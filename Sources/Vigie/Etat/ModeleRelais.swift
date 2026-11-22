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
    /// Début de la première demande des sessions sans vrai titre (titre de repli, gardé sur l'iPhone).
    /// Messages envoyés depuis l'iPhone pas encore revenus dans le fil (affichage optimiste), par fil lu.
    public internal(set) var envois: [String: [String]] = [:]
    public internal(set) var premiersMessages: [String: String] = ModeleRelais.premiersMessagesGardes()
    /// Organisation gardée sur l'iPhone (favoris par machine, état de synchro) : lue avant tout réseau.
    public internal(set) var organisation: Organisation
    @ObservationIgnored let stockage: StockageOrganisation
    @ObservationIgnored var titresDemandes: Set<String> = []
    /// Blocs d'affichage par fil, recalculés seulement quand le fil change (jamais à chaque delta ni à chaque rendu).
    @ObservationIgnored private var cacheBlocs: [String: (cle: [Int], blocs: [BlocFil])] = [:]
    /// Texte en direct par fil, un bloc à la fois ; publié dans `enEcriture` toutes les 100 ms, pas un rendu par jeton.
    @ObservationIgnored private var directs: [String: CumulDirect] = [:]
    @ObservationIgnored private var directsReflexion: [String: CumulDirect] = [:]
    @ObservationIgnored private var aPublier: Set<String> = []
    /// Dernier texte en direct remplacé par son bloc final : ce bloc prend sa place sans animation d'arrivée.
    @ObservationIgnored var texteDirectFini: [String: String] = [:]
    /// Mode vocal : chaque delta du fil principal, chaque texte final et chaque fin de tour (lecture à voix haute).
    @ObservationIgnored var observateurVocal: ((ObservationVocale) -> Void)?
    @ObservationIgnored private var publicationPrevue = false
    @ObservationIgnored private(set) var client: ClientRelais?
    @ObservationIgnored private var boucle: Task<Void, Never>?
    @ObservationIgnored private var version = -1
    @ObservationIgnored private var echecsFlux = 0
    @ObservationIgnored private var attenteReprise = LiaisonRelais.attenteMinimale

    public init(stockage: StockageOrganisation = .parDefaut()) {
        self.stockage = stockage
        organisation = stockage.lire()
    }

    func brancher(_ client: ClientRelais?) {
        arreter()
        self.client = client
        version = -1
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

    /// Les blocs du fil d'une session, ou nil s'il n'est pas chargé. Lit `fils` (donc observé), calcule une fois par
    /// état du fil (nombre, premier et dernier `seq`).
    public func blocs(_ id: String) -> [BlocFil]? {
        guard let fil = fils[id] else { return nil }
        let cle = [fil.count, fil.first?.seq ?? 0, fil.last?.seq ?? 0]
        if let c = cacheBlocs[id], c.cle == cle { return c.blocs }
        let blocs = BlocsFil.depuis(StructureFil.structurer(fil))
        cacheBlocs[id] = (cle, blocs)
        return blocs
    }

    // MARK: - Boucle de liaison

    private func veiller() async {
        while !Task.isCancelled, let client {
            do {
                try await tour(client)
            } catch ErreurRelais.nonConnecte {
                echecOrganisation("clé refusée ou révoquée")
                poser(.nonConnecte)
                return
            } catch {
                if Task.isCancelled { return }
                let raison = (error as? ErreurRelais)?.description ?? "Liaison coupée, nouvel essai."
                echecOrganisation(raison)
                poser(.coupe(raison))
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

    /// Lit le flux jusqu'à sa coupure. Rend `true` si le flux a répondu au moins une fois.
    private func suivreFlux(_ client: ClientRelais) async -> Bool {
        if let aiguilleur = client.aiguilleur { return await suivreDiffusion(aiguilleur) }
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
            case .ferme(let raison):
                Trace.info("flux", "fermé : \(raison)")
                poser(.coupe("Liaison coupée, nouvel essai."))
            }
        }
        return tenu
    }

    /// Le flux du nœud par le canal chiffré : les mêmes événements que le WebSocket direct. Un message reçu vaut
    /// acquittement (un nœud qui a déjà ce canal abonné ne le redit pas toujours).
    private func suivreDiffusion(_ aiguilleur: ClientAiguilleur) async -> Bool {
        var tenu = false
        var recus = 0
        Trace.info("flux", "aiguilleur : abonnement au flux du nœud")
        for await evenement in await aiguilleur.ouvrirDiffusion() {
            switch evenement {
            case .ouverte:
                Trace.info("flux", "aiguilleur : flux ouvert")
                if !tenu { Task { await rattraperFils() } }
                tenu = true
                poser(.connecte)
            case .message(let message):
                if !tenu {
                    tenu = true
                    poser(.connecte)
                }
                recus += 1
                appliquer(message)
            case .ferme(let raison):
                Trace.info("flux", "aiguilleur : flux fermé après \(recus) messages (\(raison))")
                poser(.coupe("Liaison coupée, nouvel essai."))
            }
        }
        return tenu
    }

    private func charger(_ client: ClientRelais) async throws {
        let e: EtatRelais = try await client.lire(LiaisonRelais.etatAvecArchivees())
        version = e.version
        sessions = e.sessions.sorted { $0.majLe > $1.majLe }
        machines = e.machines
        synchroniserOrganisation(maintenant: Date())
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
        synchroniserOrganisation(maintenant: Date())
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
        case .session(let session):
            // Une affectation invalide tous les lecteurs même à valeur égale : on n'écrit que ce qui change.
            let suite = MiseAJourParc.session(session, dans: sessions)
            if suite != sessions { sessions = suite }
            memoriserFavori(session)
        case .supprimee(let id): retirer(id)
        case .machine(let machine):
            let suite = MiseAJourParc.machine(machine, dans: machines)
            if suite != machines { machines = suite }
        case .notification(let notification): recevoirNotification(notification)
        case .evenement(let evenement): recevoirEvenement(evenement)
        case .flux(let id, let bloc, let delta, let genre, nil): ajouterDelta(id, bloc, delta, genre: genre)
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
        if case .message(let texte, _, _) = evenement.evt { retirerEnvoi(texte, de: id) }
        switch evenement.evt {
        case .texte(let texte, nil):
            observateurVocal?(.final(session: id, texte: texte))
            viderTexte(id)
        case .reflexion(_, nil): viderReflexion(id)
        case .tourFini:
            observateurVocal?(.tourFini(session: id))
            viderTexte(id)
            viderReflexion(id)
        default: break
        }
    }

    func viderTexte(_ id: String) {
        directs[id] = nil
        guard let texte = enEcriture[id] else { return }
        texteDirectFini[id] = texte
        enEcriture[id] = nil
    }

    func viderReflexion(_ id: String) {
        directsReflexion[id] = nil
        if reflexionEnCours[id] != nil { reflexionEnCours[id] = nil }
    }

    private func ajouterDelta(_ id: String, _ bloc: String, _ delta: String, genre: String?) {
        if genre == "reflexion" {
            directsReflexion[id, default: CumulDirect(bloc: bloc)].ajouter(delta, bloc: bloc)
        } else {
            directs[id, default: CumulDirect(bloc: bloc)].ajouter(delta, bloc: bloc)
            observateurVocal?(.delta(session: id, bloc: bloc, texte: delta))
        }
        aPublier.insert(id)
        guard !publicationPrevue else { return }
        publicationPrevue = true
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            self?.publierDeltas()
        }
    }

    private func publierDeltas() {
        publicationPrevue = false
        for id in aPublier {
            if let texte = directs[id]?.texte, enEcriture[id] != texte { enEcriture[id] = texte }
            if let texte = directsReflexion[id]?.texte, reflexionEnCours[id] != texte { reflexionEnCours[id] = texte }
        }
        aPublier = []
    }

    private func retirer(_ id: String) {
        sessions = MiseAJourParc.sansSession(id, dans: sessions)
        garderOrganisation(organisation.oublier(id))
        retirerFil(id)
        viderTexte(id)
        viderReflexion(id)
    }

    private func vider() {
        sessions = []
        machines = []
        notifications = []
        fils = [:]
        cacheBlocs = [:]
        enEcriture = [:]
        reflexionEnCours = [:]
        directs = [:]
        directsReflexion = [:]
        debutAtteint = []
    }

    // MARK: - Écritures du fil (appelées par ModeleFil.swift)

    /// Fusionne une tranche du fil (début, page ancienne ou rattrapage) ; `atteint` : rien n'existe avant elle.
    func fusionnerFil(_ id: String, _ tranche: [EvenementDate], atteint: Bool) {
        fils[id] = FusionFil.fusionner(fils[id] ?? [], tranche)
        if atteint {
            debutAtteint.insert(id)
            if let m = fils[id].flatMap(TitreSession.premierMessage) { retenirPremierMessage(m, de: id) }
        }
    }

    /// Remplace le fil par sa relecture complète, le relais ayant réécrit la fin.
    func remplacerFil(_ id: String, _ evenements: [EvenementDate], atteint: Bool) {
        fils[id] = evenements
        if atteint { debutAtteint.insert(id) } else { debutAtteint.remove(id) }
    }

    func retirerFil(_ id: String) {
        fils[id] = nil
        cacheBlocs[id] = nil
        debutAtteint.remove(id)
    }
}
#endif
