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

/// Un nœud connu de l'iPhone : son identité publique (apprise à l'accord, donc appairé) et son nom.
public struct NoeudConnu: Codable, Sendable, Equatable {
    public var identite: String?
    public var nom: String?

    public init(identite: String? = nil, nom: String? = nil) {
        self.identite = identite
        self.nom = nom
    }
}

/// Un nœud tel que les réglages le montrent : présence, appairage, préférence et nœud actuellement relié.
public struct NoeudVu: Sendable, Equatable {
    public let id: String
    public let nom: String
    public let enLigne: Bool
    public let sansEcran: Bool
    public let appaire: Bool
    public let prefere: Bool
    public let actif: Bool

    public init(id: String, nom: String, enLigne: Bool, sansEcran: Bool, appaire: Bool, prefere: Bool, actif: Bool) {
        self.id = id
        self.nom = nom
        self.enLigne = enLigne
        self.sansEcran = sansEcran
        self.appaire = appaire
        self.prefere = prefere
        self.actif = actif
    }
}

public actor ClientAiguilleur {
    public struct Etat: Codable, Sendable, Equatable {
        public var adresse: String        // https://… ou http://… de l'aiguilleur
        public var membre: String         // id de l'iPhone chez l'aiguilleur
        public var jeton: String          // jeton de membre (Bearer du WebSocket /aiguilleur)
        public var noeud: String?         // id du nœud visé par le lien en cours (choisi par la sélection)
        public var noeuds: [String: NoeudConnu] // nœuds connus, par identifiant ; appairé = identité connue
        public var prefere: String?       // nœud préféré, réglé par Chris

        public init(
            adresse: String, membre: String, jeton: String, noeud: String? = nil,
            noeuds: [String: NoeudConnu] = [:], prefere: String? = nil
        ) {
            self.adresse = adresse
            self.membre = membre
            self.jeton = jeton
            self.noeud = noeud
            self.noeuds = noeuds
            self.prefere = prefere
        }

        /// Les nœuds appariés (identité connue), par identifiant.
        public var appaires: Set<String> { Set(noeuds.filter { $0.value.identite != nil }.keys) }

        public func estAppaire(_ id: String) -> Bool { noeuds[id]?.identite != nil }

        private enum CodingKeys: String, CodingKey { case adresse, membre, jeton, noeud, noeuds, prefere }
        /// Forme d'avant la multi-liaison : un seul nœud, sa clé et son nom au niveau racine.
        private enum Heritage: String, CodingKey { case identiteNoeud, nomNoeud }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            adresse = try c.decode(String.self, forKey: .adresse)
            membre = try c.decode(String.self, forKey: .membre)
            jeton = try c.decode(String.self, forKey: .jeton)
            noeud = try c.decodeIfPresent(String.self, forKey: .noeud)
            noeuds = try c.decodeIfPresent([String: NoeudConnu].self, forKey: .noeuds) ?? [:]
            prefere = try c.decodeIfPresent(String.self, forKey: .prefere)
            let ancien = try decoder.container(keyedBy: Heritage.self)
            if noeuds.isEmpty, let id = noeud, let identite = try ancien.decodeIfPresent(String.self, forKey: .identiteNoeud) {
                noeuds[id] = NoeudConnu(identite: identite, nom: try ancien.decodeIfPresent(String.self, forKey: .nomNoeud))
            }
        }
    }

    public enum Lien: Sendable, Equatable {
        case deconnecte, connexion, rechercheNoeud, attenteAccord(empreinte: String), ouvert, refuse(String)
        /// L'appareil est révoqué : le lien ne se rouvre pas, sans nouvel appairage.
        case revoque
    }

    var etat: Etat
    let graines: GrainesIdentite
    let nomAppareil: String
    let surEtat: @Sendable (Etat) async -> Void
    let surLien: @Sendable (Lien) async -> Void
    /// Les nœuds vus (présence, appairage, préférence) : les réglages les montrent.
    let surNoeuds: @Sendable ([NoeudVu]) async -> Void
    let fabrique: FabriqueTransport
    let delais: DelaisClient
    let moi: Chiffrement.Identite?
    let requetes = TableRequetes()
    var delaiReprise: Duration
    var transport: (any TransportAiguilleur)?
    var boucle: Task<Void, Never>?
    var canaux: [String: Chiffrement.CanalAppareil] = [:]
    var canalCourant: String?
    /// Morceaux des corps reçus en route (réponses, événements du flux).
    var reassemblage = ReassemblageMorceaux()
    /// Le flux en direct du nœud, quand l'appli le suit (voir AiguilleurFlux.swift).
    var diffusion: AsyncStream<EvenementDiffusion>.Continuation?
    /// Identifiant du flux courant : la fin d'un flux remplacé ne doit pas toucher le suivant.
    var diffusionCourante: UUID?
    /// Les terminaux de machine ouverts par l'appli, par identifiant (voir AiguilleurTerminal.swift).
    var terminaux: [String: AsyncStream<EvenementTerminal>.Continuation] = [:]
    var presence: [ProtocoleAiguilleur.Membre] = []
    /// Révocation reçue : le lien ne se rouvre plus.
    var revoque = false
    /// Refus ou révocation : aucun canal ne se rouvre sans un nouvel appairage.
    var bloque = false
    /// Nœuds refusés ou révoqués pendant cette session : exclus de la sélection jusqu'à un choix de Chris.
    var refuses: Set<String> = []

    public init(
        etat: Etat, graines: GrainesIdentite, nomAppareil: String,
        surEtat: @escaping @Sendable (Etat) async -> Void, surLien: @escaping @Sendable (Lien) async -> Void,
        surNoeuds: @escaping @Sendable ([NoeudVu]) async -> Void = { _ in }
    ) {
        self.etat = etat
        self.graines = graines
        self.nomAppareil = nomAppareil
        self.surEtat = surEtat
        self.surLien = surLien
        self.surNoeuds = surNoeuds
        fabrique = TransportWebSocket.ouvrir
        delais = .defaut
        moi = try? graines.identite()
        delaiReprise = DelaisClient.defaut.repriseInitiale
    }

    init(
        etat: Etat, graines: GrainesIdentite, nomAppareil: String,
        surEtat: @escaping @Sendable (Etat) async -> Void, surLien: @escaping @Sendable (Lien) async -> Void,
        fabrique: @escaping FabriqueTransport, delais: DelaisClient,
        surNoeuds: @escaping @Sendable ([NoeudVu]) async -> Void = { _ in }
    ) {
        self.etat = etat
        self.graines = graines
        self.nomAppareil = nomAppareil
        self.surEtat = surEtat
        self.surLien = surLien
        self.surNoeuds = surNoeuds
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

    /// Choisit le nœud préféré (ou aucun, avec nil) : le lien passe à ce nœud dès qu'il est en ligne.
    public func prefererNoeud(_ id: String?) async {
        etat.prefere = id
        if let id { refuses.remove(id) }
        await surEtat(etat)
        await cibler()
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
        finirDiffusion("client arrêté")
        finirTerminaux("client arrêté")
        await requetes.echouerTout(ErreurAiguilleur("client arrêté"))
        await surLien(.deconnecte)
    }

    /// Une requête de l'API clients dans le canal chiffré ; attend l'ouverture du lien (20 s au plus).
    public func requete(
        methode: String, chemin: String, corps: String?, delai: Duration? = nil
    ) async throws -> ReponseRequete {
        try await requeteDansCanal(methode: methode, chemin: chemin, corps: corps, codage: nil, type: nil, delai: delai)
    }

    /// Une requête dont le corps est binaire (fichier envoyé) : il part en base64, en morceaux s'il est grand.
    public func requeteOctets(methode: String, chemin: String, corps: Data, type: String) async throws -> ReponseRequete {
        try await requeteDansCanal(
            methode: methode, chemin: chemin, corps: corps.base64EncodedString(), codage: "base64", type: type
        )
    }

    private func requeteDansCanal(
        methode: String, chemin: String, corps: String?, codage: String?, type: String?, delai: Duration? = nil
    ) async throws -> ReponseRequete {
        let canal = try await canalOuvert()
        let ref = UUID().uuidString.lowercased()
        await requetes.prevoir(ref)
        armerDelaiReponse(ref, delai ?? delais.reponse)
        guard await envoyerApi(canal, ref: ref, methode: methode, chemin: chemin, corps: corps, codage: codage, type: type)
        else {
            await requetes.annuler(ref)
            throw ErreurAiguilleur("requête non envoyée : lien fermé ou message trop grand")
        }
        return try await requetes.attendre(ref)
    }

    /// Une requête de l'API : les morceaux de son corps partent d'abord, puis le message qui les annonce.
    private func envoyerApi(
        _ canal: Chiffrement.CanalAppareil, ref: String, methode: String, chemin: String,
        corps: String?, codage: String?, type: String?
    ) async -> Bool {
        let morceaux = corps.map { DecoupeMorceaux.de($0) } ?? []
        if morceaux.isEmpty {
            return await canal.envoyer(.api(ref: ref, methode: methode, chemin: chemin, corps: corps,
                                            codage: codage, type: type))
        }
        for (rang, morceau) in morceaux.enumerated() {
            guard await canal.envoyer(.morceau(ref: ref, rang: rang, corps: morceau)) else { return false }
        }
        return await canal.envoyer(.api(ref: ref, methode: methode, chemin: chemin, corps: "",
                                        codage: codage, type: type, morceaux: morceaux.count))
    }

    func canalOuvert() async throws -> Chiffrement.CanalAppareil {
        let fin = ContinuousClock.now.advanced(by: delais.ouverture)
        while ContinuousClock.now < fin {
            if let id = canalCourant, let canal = canaux[id], await canal.estOuvert { return canal }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw ErreurAiguilleur("lien vers le nœud non ouvert : réessaie dans un instant")
    }

    func armerDelaiReponse(_ ref: String, _ delai: Duration) {
        Task {
            try? await Task.sleep(for: delai)
            await self.requetes.echouer(ref, ErreurAiguilleur("pas de réponse du nœud"))
        }
    }
}
