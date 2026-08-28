// La besace vivante : l'état partagé du monde Saily, tenu par l'environnement.
// Le pendant du `Salon` d'EchoHub. Elle orchestre le noyau pur (`EtatBoite`,
// `ClientSaily`, `ConnexionSync`) ; elle ne contient AUCUNE règle de forme.
#if canImport(SwiftUI)
import SwiftUI
import SailyNoyau

/// Où en est la liaison avec le serveur. Un écran qui ne sait pas dire « en
/// ligne », « hors ligne » et « je démarre » finit par mentir dans les trois cas.
public enum EtatLiaison: Equatable, Sendable {
    case demarrage
    case enLigne
    case horsLigne
    case injoignable(String)
}

@Observable
@MainActor
public final class Boite {
    // MARK: - Ce que les écrans lisent

    /// Les items visibles, épingles en tête. Dérivé de l'état pur : c'est lui la
    /// source de vérité, jamais une copie qu'il faudrait tenir à jour.
    public var items: [Item] { etat.visibles }
    public var tags: [String] { etat.tags }
    public private(set) var liaison: EtatLiaison = .demarrage
    /// Vrai une fois le premier snapshot (ou delta REST) reçu : distingue « rien
    /// capturé » d'« en train de charger ».
    public private(set) var premierChargementFait = false
    public private(set) var reglages: ReglagesServeur = .parDefaut
    /// Le nombre d'écritures en attente de rejeu (affiché quand > 0).
    public var enAttente: Int { etat.enAttente.count }

    // MARK: - Ce qui n'appartient qu'à la besace

    @ObservationIgnored private var etatInterne = EtatBoite()
    /// Passe par un accès observé : muter `etat` invalide les vues qui lisent
    /// `items`. `@ObservationIgnored` sur le stockage, l'observation est portée
    /// par ce drapeau de version.
    @ObservationIgnored private var version = 0
    private var etat: EtatBoite {
        get {
            _ = version
            return etatInterne
        }
        set {
            etatInterne = newValue
            version += 1
        }
    }

    @ObservationIgnored private let client: ClientSaily
    @ObservationIgnored private let connexion: ConnexionSync
    @ObservationIgnored private let gestionnaire: GestionnaireReglagesServeur
    @ObservationIgnored private let clientId: String
    @ObservationIgnored private var boucleFlux: Task<Void, Never>?

    public init() {
        let dossier = FileManager.dossierSailyParDefaut()
        gestionnaire = GestionnaireReglagesServeur(
            magasin: MagasinReglagesServeurDisque(dossier: dossier)
        )
        clientId = IdentiteClient.stable(dossier: dossier)
        client = ClientSaily()
        connexion = ConnexionSync(client: client)
    }

    // MARK: - Cycle de vie

    /// Premier geste : relire le réglage, le poser au client, tirer un delta
    /// REST (utile même WS fermé), puis ouvrir le socket et consommer son flux.
    public func demarrer() async {
        guard boucleFlux == nil else { return }
        reglages = await gestionnaire.actuels()
        await client.configurer(reglages)
        await synchroniserParRest()
        lancerFlux()
    }

    /// Réveil au premier plan : re-tirer un delta et relancer le socket si
    /// besoin. Le WS a pu tomber pendant la mise en veille.
    public func reprendre() async {
        await synchroniserParRest()
        await connexion.demarrer()
    }

    /// Mise en arrière-plan sans maintien de veille : on ferme le socket, la
    /// reconnexion repartira au réveil. L'état capturé reste sur le disque du
    /// serveur — rien à perdre ici.
    public func suspendre() {
        Task { await connexion.arreter() }
    }

    private func lancerFlux() {
        boucleFlux = Task { [connexion] in
            await connexion.demarrer()
            for await evenement in await connexion.flux() {
                await self.traiter(evenement)
            }
        }
    }

    private func traiter(_ evenement: EvenementSync) async {
        switch evenement {
        case .connecte:
            liaison = .enLigne
            await envoyerHello()
            await rejouerLaFile()
        case let .message(message):
            appliquer(message)
        case .deconnecte:
            if liaison == .enLigne { liaison = .horsLigne }
        }
    }

    private func appliquer(_ message: MessageServeur) {
        var courant = etat
        courant.appliquer(message, clientId: clientId)
        etat = courant
        if case .snapshot = message { premierChargementFait = true }
    }

    // MARK: - Synchro REST

    /// Tire le delta depuis notre horloge et l'applique. Sert au démarrage, au
    /// réveil, et de repli quand le socket est fermé.
    private func synchroniserParRest() async {
        do {
            let items = try await client.delta(depuis: etat.since)
            var courant = etat
            courant.appliquer(snapshot: items)
            etat = courant
            premierChargementFait = true
            if liaison == .demarrage { liaison = .horsLigne }
        } catch let erreur as ErreurSaily {
            if erreur.estAnnulation { return }
            premierChargementFait = true
            liaison = .injoignable(erreur.libelle)
        } catch {
            premierChargementFait = true
            liaison = .injoignable(error.localizedDescription)
        }
    }

    private func envoyerHello() async {
        do {
            try await connexion.envoyer(.hello(clientId: clientId, since: etat.since))
        } catch {
            Journal.echec("hello non envoyé : \(error)")
        }
    }

    // MARK: - Capture

    /// Capture une note texte.
    public func capturerNote(_ texte: String, tags: [String] = []) async {
        let coupe = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !coupe.isEmpty else { return }
        await capturer(ItemInput(id: nouvelId(), kind: .note, text: coupe, tags: tags))
    }

    /// Capture un lien. L'URL brute sert de texte si aucune légende.
    public func capturerLien(_ url: String, legende: String = "", tags: [String] = []) async {
        let coupe = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !coupe.isEmpty else { return }
        await capturer(ItemInput(
            id: nouvelId(), kind: .lien, text: legende, url: coupe, tags: tags
        ))
    }

    /// Capture un blob : téléverse d'abord, puis crée l'item qui le référence.
    /// Un échec de téléversement laisse l'app propre — rien n'est capturé à
    /// moitié.
    public func capturerBlob(
        _ octets: Data, kind: EspeceItem, nomFichier: String, typeMime: String,
        legende: String = "", tags: [String] = []
    ) async {
        do {
            let depot = try await client.televerserBlob(
                octets: octets, nomFichier: nomFichier, typeMime: typeMime
            )
            await capturer(ItemInput(
                id: nouvelId(), kind: kind, text: legende, blob: depot.blob,
                mime: depot.mime, tags: tags
            ))
        } catch {
            liaison = .injoignable("Téléversement refusé — \((error as? ErreurSaily)?.libelle ?? "\(error)")")
        }
    }

    /// Épingle/désépingle. Reconstruit l'entrée depuis l'item courant.
    public func basculerEpingle(_ item: Item) async {
        var input = ItemInput(depuis: item)
        input = ItemInput(
            id: input.id, kind: input.kind, text: input.text, url: input.url,
            blob: input.blob, mime: input.mime, tags: input.tags, pinned: !item.pinned
        )
        await capturer(input)
    }

    /// Supprime un item (optimiste, puis diffusion). Idempotent côté serveur.
    public func supprimer(_ item: Item) async {
        var courant = etat
        courant.supprimerLocalement(id: item.id, maintenant: maintenantMs())
        etat = courant
        do {
            try await client.supprimer(id: item.id, clientId: clientId)
        } catch let erreur as ErreurSaily where !erreur.estAnnulation {
            etat.enfiler(.delete(id: item.id, clientId: clientId))
            liaison = .horsLigne
        } catch {}
    }

    /// Le chemin commun de toute écriture : optimisme local, puis POST REST ;
    /// en cas d'échec réseau, on enfile pour rejeu et on garde l'optimisme.
    private func capturer(_ input: ItemInput) async {
        var courant = etat
        courant.poserLocalement(input, maintenant: maintenantMs())
        etat = courant
        do {
            let confirme = try await client.upsert(input, clientId: clientId)
            var apres = etat
            apres.appliquer(item: confirme)
            etat = apres
        } catch let erreur as ErreurSaily where !erreur.estAnnulation {
            etat.enfiler(.upsert(item: input, clientId: clientId))
            liaison = .horsLigne
        } catch {}
    }

    /// Rejoue les écritures accumulées hors ligne, dans l'ordre, par REST.
    /// Idempotent : un item déjà passé ne fait rien de plus.
    private func rejouerLaFile() async {
        var courant = etat
        let messages = courant.viderFile()
        etat = courant
        for message in messages { await rejouer(message) }
    }

    private func rejouer(_ message: MessageClient) async {
        do {
            switch message {
            case let .upsert(item, _):
                let confirme = try await client.upsert(item, clientId: clientId)
                var apres = etat
                apres.appliquer(item: confirme)
                etat = apres
            case let .delete(id, _):
                try await client.supprimer(id: id, clientId: clientId)
            case .hello, .ping:
                break
            }
        } catch {
            // Un échec au rejeu : on ré-enfile pour la prochaine reconnexion.
            etat.enfiler(message)
        }
    }

    // MARK: - Réglages et santé

    public func mettreAJourReglages(_ nouveaux: ReglagesServeur) async {
        reglages = nouveaux
        await gestionnaire.mettreAJour(nouveaux)
        await client.configurer(nouveaux)
        await connexion.arreter()
        await synchroniserParRest()
        await connexion.demarrer()
    }

    public func sonder() async -> Result<SanteServeur, ErreurSaily> {
        await client.sonder()
    }

    /// Charge les octets d'un blob pour l'aperçu. Toléré à l'échec : une
    /// vignette absente vaut mieux qu'un crash.
    public func chargerBlob(_ nom: String) async -> Data? {
        do {
            return try await client.blob(nom)
        } catch {
            Journal.echec("aperçu de blob \(nom) non chargé : \(error)")
            return nil
        }
    }

    // MARK: - Outils

    private func nouvelId() -> String { "ios-\(UUID().uuidString)" }
    private func maintenantMs() -> Int { Int(Date().timeIntervalSince1970 * 1000) }
}

extension FileManager {
    /// Le dossier de Saily : survit aux lancements. Distinct de celui d'EchoHub
    /// pour que les deux mondes ne se marchent pas dessus.
    static func dossierSailyParDefaut() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (base ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Saily", isDirectory: true)
    }
}
#endif
