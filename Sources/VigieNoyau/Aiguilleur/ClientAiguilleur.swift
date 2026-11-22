import Foundation

// Responsabilité : l'API publique du client de l'aiguilleur côté iPhone — appairage par code, lancement et
// arrêt du lien, requêtes de l'API clients dans le canal chiffré. La boucle du lien est dans
// ClientAiguilleurLien.swift, les réactions aux canaux dans ClientAiguilleurHote.swift.

/// Délais du client : attente de l'ouverture du canal, réponse à une requête, reprise après coupure (doublée).
struct DelaisClient: Sendable {
    let ouverture: Duration
    let reponse: Duration
    let repriseInitiale: Duration
    let repriseMax: Duration

    static let defaut = DelaisClient(
        ouverture: .seconds(20), reponse: .seconds(20), repriseInitiale: .seconds(2), repriseMax: .seconds(30)
    )
    /// Délais courts pour les tests sans réseau.
    static let rapides = DelaisClient(
        ouverture: .milliseconds(200), reponse: .milliseconds(500),
        repriseInitiale: .milliseconds(20), repriseMax: .milliseconds(100)
    )
}

public actor ClientAiguilleur {
    public struct Etat: Codable, Sendable, Equatable {
        public var adresse: String        // https://… ou http://… de l'aiguilleur
        public var membre: String         // id de l'iPhone chez l'aiguilleur
        public var jeton: String          // jeton de membre (Bearer du WebSocket /aiguilleur)
        public var noeud: String?         // id du nœud choisi (appris par `presence`)
        public var identiteNoeud: String? // identité publique exportée du nœud, apprise à l'accord
        public var nomNoeud: String?

        public init(
            adresse: String, membre: String, jeton: String, noeud: String? = nil,
            identiteNoeud: String? = nil, nomNoeud: String? = nil
        ) {
            self.adresse = adresse
            self.membre = membre
            self.jeton = jeton
            self.noeud = noeud
            self.identiteNoeud = identiteNoeud
            self.nomNoeud = nomNoeud
        }
    }

    public enum Lien: Sendable, Equatable {
        case deconnecte, connexion, rechercheNoeud, attenteAccord(empreinte: String), ouvert, refuse(String)
    }

    var etat: Etat
    let graines: GrainesIdentite
    let nomAppareil: String
    let surEtat: @Sendable (Etat) async -> Void
    let surLien: @Sendable (Lien) async -> Void
    let fabrique: FabriqueTransport
    let delais: DelaisClient
    let moi: Chiffrement.Identite?
    let requetes = TableRequetes()
    var delaiReprise: Duration
    var transport: (any TransportAiguilleur)?
    var boucle: Task<Void, Never>?
    var canaux: [String: Chiffrement.CanalAppareil] = [:]
    var canalCourant: String?
    var presence: [ProtocoleAiguilleur.Membre] = []
    /// Révocation reçue : le lien ne se rouvre plus.
    var revoque = false
    /// Refus ou révocation : aucun canal ne se rouvre sans un nouvel appairage.
    var bloque = false

    public init(
        etat: Etat, graines: GrainesIdentite, nomAppareil: String,
        surEtat: @escaping @Sendable (Etat) async -> Void, surLien: @escaping @Sendable (Lien) async -> Void
    ) {
        self.etat = etat
        self.graines = graines
        self.nomAppareil = nomAppareil
        self.surEtat = surEtat
        self.surLien = surLien
        fabrique = TransportWebSocket.ouvrir
        delais = .defaut
        moi = try? graines.identite()
        delaiReprise = DelaisClient.defaut.repriseInitiale
    }

    init(
        etat: Etat, graines: GrainesIdentite, nomAppareil: String,
        surEtat: @escaping @Sendable (Etat) async -> Void, surLien: @escaping @Sendable (Lien) async -> Void,
        fabrique: @escaping FabriqueTransport, delais: DelaisClient
    ) {
        self.etat = etat
        self.graines = graines
        self.nomAppareil = nomAppareil
        self.surEtat = surEtat
        self.surLien = surLien
        self.fabrique = fabrique
        self.delais = delais
        moi = try? graines.identite()
        delaiReprise = delais.repriseInitiale
    }

    /// Appairage par code : l'aiguilleur donne l'identifiant et le jeton du membre. Le code est à usage unique.
    public static func appairer(
        adresse: URL, code: String, nom: String, graines: GrainesIdentite
    ) async throws -> Etat {
        let identite = try graines.identite()
        let appairage = try await LienAiguilleur.appairer(
            adresse: adresse, code: code, nom: nom, cle: Chiffrement.Identites.exporter(identite.publique)
        )
        return Etat(adresse: adresse.absoluteString, membre: appairage.id, jeton: appairage.jeton)
    }

    /// Lance la boucle du lien : connexion, présence, canal vers le nœud ; reprise automatique après coupure.
    public func demarrer() {
        guard boucle == nil else { return }
        boucle = Task { await self.boucleLien() }
    }

    /// Arrête le lien et ses canaux ; les requêtes en vol échouent.
    public func arreter() async {
        boucle?.cancel()
        boucle = nil
        if let tache = transport { await tache.fermer() }
        transport = nil
        for canal in Array(canaux.values) { await canal.surFermetureDistante() }
        canaux = [:]
        canalCourant = nil
        await requetes.echouerTout(ErreurAiguilleur("client arrêté"))
        await surLien(.deconnecte)
    }

    /// Une requête de l'API clients dans le canal chiffré ; attend l'ouverture du lien (20 s au plus).
    public func requete(methode: String, chemin: String, corps: String?) async throws -> (statut: Int, corps: String) {
        let canal = try await canalOuvert()
        let ref = UUID().uuidString.lowercased()
        await requetes.prevoir(ref)
        armerDelaiReponse(ref)
        guard await canal.envoyer(.api(ref: ref, methode: methode, chemin: chemin, corps: corps)) else {
            await requetes.annuler(ref)
            throw ErreurAiguilleur("requête non envoyée : lien fermé ou message trop grand")
        }
        let reponse = try await requetes.attendre(ref)
        return (reponse.statut, reponse.corps)
    }

    func canalOuvert() async throws -> Chiffrement.CanalAppareil {
        let fin = ContinuousClock.now.advanced(by: delais.ouverture)
        while ContinuousClock.now < fin {
            if let id = canalCourant, let canal = canaux[id], await canal.estOuvert { return canal }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw ErreurAiguilleur("lien vers le nœud non ouvert : réessaie dans un instant")
    }

    func armerDelaiReponse(_ ref: String) {
        let delai = delais.reponse
        Task {
            try? await Task.sleep(for: delai)
            await self.requetes.echouer(ref, ErreurAiguilleur("pas de réponse du nœud"))
        }
    }
}
