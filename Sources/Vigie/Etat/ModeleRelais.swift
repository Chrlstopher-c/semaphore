// L'état du parc vu par Vigie. Au premier plan : un WebSocket `/api/flux` pousse chaque changement ; après trois
// échecs, le long-poll `/api/attente` reprend la main jusqu'à la prochaine réussite. Le fil d'une session se charge
// à part (ModeleFil.swift), les commandes sont dans Commandes.swift.
#if canImport(SwiftUI)
import Foundation
import Observation
import VigieNoyau

/// La liaison avec le relais, telle que l'app l'affiche.
public enum Lien: Equatable { case attente, connecte, coupe(String), nonConnecte }

@MainActor @Observable
public final class ModeleRelais {
    public private(set) var lien: Lien = .attente
    public private(set) var sessions: [Session] = []
    public private(set) var machines: [Machine] = []
    public private(set) var notifications: [NotificationRelais] = []
    public private(set) var reveilPossible: [String] = []
    /// Fil chargé par session, trié par `seq`, sans doublon. Absent : fil non chargé ou écran quitté.
    public private(set) var fils: [String: [EvenementDate]] = [:]
    /// Texte en cours d'écriture (deltas `flux` du fil principal), vidé par le texte final.
    public private(set) var enEcriture: [String: String] = [:]
    public private(set) var reflexionEnCours: [String: String] = [:]
    /// Sessions dont le fil est connu jusqu'à son tout premier événement.
    public private(set) var debutAtteint: Set<String> = []
    @ObservationIgnored private(set) var client: ClientRelais?
    @ObservationIgnored private var boucle: Task<Void, Never>?
    @ObservationIgnored private var version = -1
    @ObservationIgnored private var echecsFlux = 0
    @ObservationIgnored private var attenteReprise = LiaisonRelais.attenteMinimale

    public init() {}

    func brancher(_ client: ClientRelais?) {
        arreter()
        self.client = client
        lien = client == nil ? .nonConnecte : .attente
        if client == nil { vider() }
    }

    func demarrer() {
        guard client != nil, boucle == nil else { return }
        echecsFlux = 0
        attenteReprise = LiaisonRelais.attenteMinimale
        boucle = Task { [weak self] in await self?.veiller() }
    }

    func arreter() {
        boucle?.cancel()
        boucle = nil
        if lien == .connecte { poser(.attente) }
    }

    public func session(_ id: String) -> Session? {
        sessions.first { $0.id == id }
    }

    public func machine(_ id: String) -> Machine? {
        machines.first { $0.id == id }
    }

    // MARK: - Boucle de liaison

    private func veiller() async {
        while !Task.isCancelled, let client {
            do {
                try await tour(client)
            } catch ErreurRelais.nonConnecte {
                poser(.nonConnecte)
                return
            } catch {
                if Task.isCancelled { return }
                poser(.coupe("\(error)"))
                await dormirReprise()
            }
        }
    }

    /// Un tour : état complet, puis flux tant qu'il tient. Après trois échecs du flux, un tour de long-poll.
    private func tour(_ client: ClientRelais) async throws {
        try await charger(client)
        let tenu = await suivreFlux(client)
        if tenu {
            echecsFlux = 0
            attenteReprise = LiaisonRelais.attenteMinimale
        } else {
            echecsFlux += 1
        }
        if echecsFlux < LiaisonRelais.echecsAvantRepli {
            await dormirReprise()
            return
        }
        try await attendre(client)
        await rattraperFils()
    }

    /// Lit le flux jusqu'à sa coupure. Rend `true` si le WebSocket a répondu au moins une fois.
    private func suivreFlux(_ client: ClientRelais) async -> Bool {
        let flux: FluxRelais
        do {
            flux = try FluxRelais(client: client)
        } catch {
            Trace.erreur("flux", "ouverture impossible", error)
            return false
        }
        flux.ouvrir()
        defer { flux.fermer() }
        var tenu = false
        for await evenement in flux.evenements {
            switch evenement {
            case .ouvert:
                if !tenu { Task { await rattraperFils() } }
                tenu = true
                poser(.connecte)
            case .message(let message): appliquer(message)
            case .ferme(let raison): poser(.coupe(raison))
            }
        }
        return tenu
    }

    private func charger(_ client: ClientRelais) async throws {
        let e: EtatRelais = try await client.lire(LiaisonRelais.etatAvecArchivees())
        version = e.version
        sessions = e.sessions.sorted { $0.majLe > $1.majLe }
        machines = e.machines
        notifications = e.notifications
        reveilPossible = e.reveilPossible
        await CentreAlerte.partage.sonner(e.notifications)
    }

    /// Long-poll de repli : rend dès qu'il y a du nouveau, ou à l'échéance.
    private func attendre(_ client: ClientRelais) async throws {
        let dernier = notifications.first?.seq ?? 0
        let chemin = LiaisonRelais.attenteAvecArchivees(version: version, notifications: dernier)
        let r: ReponseAttente = try await client.lire(chemin)
        version = r.version
        sessions = r.sessions.sorted { $0.majLe > $1.majLe }
        machines = r.machines
        if !r.notifications.isEmpty {
            notifications = MiseAJourParc.notifications(r.notifications, dans: notifications)
            await CentreAlerte.partage.sonner(r.notifications)
        }
        poser(.connecte)
    }

    private func dormirReprise() async {
        try? await Task.sleep(nanoseconds: UInt64(attenteReprise) * 1_000_000_000)
        attenteReprise = LiaisonRelais.attenteSuivante(attenteReprise)
    }

    private func poser(_ nouveau: Lien) {
        if lien != nouveau { lien = nouveau }
    }

    // MARK: - Messages du relais

    /// Applique un message du flux au parc, au fil ou aux écritures en cours.
    private func appliquer(_ message: MessageClient) {
        switch message {
        case .session(let session): sessions = MiseAJourParc.session(session, dans: sessions)
        case .supprimee(let id): retirer(id)
        case .machine(let machine): machines = MiseAJourParc.machine(machine, dans: machines)
        case .notification(let notification): recevoirNotification(notification)
        case .evenement(let evenement): recevoirEvenement(evenement)
        case .flux(let id, _, let delta, let genre, nil): ajouterDelta(id, delta, genre: genre)
        case .flux: break
        case .filModifie(let id): Task { await relireFil(id) }
        case .inconnu: break
        }
    }

    private func recevoirNotification(_ notification: NotificationRelais) {
        notifications = MiseAJourParc.notifications([notification], dans: notifications)
        Task { await CentreAlerte.partage.sonner([notification]) }
    }

    /// L'événement rejoint son fil s'il est chargé ; un texte ou une réflexion finale vide l'écriture en cours.
    private func recevoirEvenement(_ evenement: EvenementDate) {
        let id = evenement.sessionId
        if let fil = fils[id] { fils[id] = FusionFil.ajouter(evenement, au: fil) }
        switch evenement.evt {
        case .texte(_, nil): enEcriture[id] = nil
        case .reflexion(_, nil): reflexionEnCours[id] = nil
        case .tourFini:
            enEcriture[id] = nil
            reflexionEnCours[id] = nil
        default: break
        }
    }

    private func ajouterDelta(_ id: String, _ delta: String, genre: String?) {
        if genre == "reflexion" {
            reflexionEnCours[id, default: ""] += delta
        } else {
            enEcriture[id, default: ""] += delta
        }
    }

    private func retirer(_ id: String) {
        sessions = MiseAJourParc.sansSession(id, dans: sessions)
        retirerFil(id)
        enEcriture[id] = nil
        reflexionEnCours[id] = nil
    }

    private func vider() {
        sessions = []
        machines = []
        notifications = []
        fils = [:]
        enEcriture = [:]
        reflexionEnCours = [:]
        debutAtteint = []
    }

    // MARK: - Écritures du fil (appelées par ModeleFil.swift)

    /// Fusionne une tranche du fil (début, page ancienne ou rattrapage) ; `atteint` : rien n'existe avant elle.
    func fusionnerFil(_ id: String, _ tranche: [EvenementDate], atteint: Bool) {
        fils[id] = FusionFil.fusionner(fils[id] ?? [], tranche)
        if atteint { debutAtteint.insert(id) }
    }

    /// Remplace le fil par sa relecture complète, le relais ayant réécrit la fin.
    func remplacerFil(_ id: String, _ evenements: [EvenementDate], atteint: Bool) {
        fils[id] = evenements
        if atteint { debutAtteint.insert(id) } else { debutAtteint.remove(id) }
    }

    func retirerFil(_ id: String) {
        fils[id] = nil
        debutAtteint.remove(id)
    }
}
#endif
