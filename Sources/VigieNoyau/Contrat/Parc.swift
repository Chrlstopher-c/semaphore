import Foundation

// Le parc, les notifications et l'état global, tels que le relais les rend (miroir de `commun/api-clients.ts`
// et de `commun/comptes.ts`). Une machine dont l'état ou l'accès ne se lit pas reste lisible : ces champs tombent.

public struct EtatMachine: Codable, Sendable, Equatable {
    public struct Occupation: Codable, Sendable, Equatable {
        public let utilisee: Double
        public let totale: Double
        public var ratio: Double { totale > 0 ? utilisee / totale : 0 }
    }

    public struct OccupationDisque: Codable, Sendable, Equatable {
        public let utilise: Double
        public let total: Double
        public var ratio: Double { total > 0 ? utilise / total : 0 }
    }

    public let cpu: Double
    public let memoire: Occupation
    public let disque: OccupationDisque
    public let charge: Double
    public let demarreeDepuis: Int
}

/// Accès d'une machine au relais : `local`, `connecte`, `connexion`, `injoignable`, `non_installe`.
public struct AccesMachine: Codable, Sendable, Equatable {
    public let etat: String
    public let detail: String?
    public let depuis: String
}

/// Une fenêtre de quota : part consommée (0 à 100) et moment de sa remise à zéro.
public struct FenetreUsage: Codable, Sendable, Equatable {
    public let libelle: String
    public let pourcent: Double
    public let reinitialiseLe: String?
}

/// Identité et usage d'un compte Claude Code sur une machine, tels que relevés par le poste.
public struct EtatCompte: Codable, Sendable, Equatable {
    public let id: String
    public let defaut: Bool
    public let connecte: Bool
    public let email: String?
    public let organisation: String?
    public let abonnement: String?
    public let session: FenetreUsage?
    public let semaine: FenetreUsage?
    public let autres: [FenetreUsage]
    public let probleme: String?
    public let releveLe: String

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        defaut = try c.decode(Bool.self, forKey: .defaut)
        connecte = try c.decode(Bool.self, forKey: .connecte)
        email = c.facultatif(String.self, .email)
        organisation = c.facultatif(String.self, .organisation)
        abonnement = c.facultatif(String.self, .abonnement)
        session = c.facultatif(FenetreUsage.self, .session)
        semaine = c.facultatif(FenetreUsage.self, .semaine)
        autres = (try? c.decode([Tolere<FenetreUsage>].self, forKey: .autres))?.compactMap(\.valeur) ?? []
        probleme = c.facultatif(String.self, .probleme)
        releveLe = try c.decode(String.self, forKey: .releveLe)
    }
}

public struct Machine: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let description: String
    public let racines: [String]
    public let projets: [Projet]
    public let comptes: [String]
    public let etatComptes: [EtatCompte]
    public let version: String
    public let etat: EtatMachine?
    public let acces: AccesMachine?
    public let derniereVue: String
    public let enLigne: Bool

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        description = try c.decode(String.self, forKey: .description)
        racines = try c.decode([String].self, forKey: .racines)
        projets = try c.decode([Projet].self, forKey: .projets)
        comptes = try c.decode([String].self, forKey: .comptes)
        etatComptes = (try? c.decode([Tolere<EtatCompte>].self, forKey: .etatComptes))?.compactMap(\.valeur) ?? []
        version = try c.decode(String.self, forKey: .version)
        etat = c.facultatif(EtatMachine.self, .etat)
        acces = c.facultatif(AccesMachine.self, .acces)
        derniereVue = try c.decode(String.self, forKey: .derniereVue)
        enLigne = try c.decode(Bool.self, forKey: .enLigne)
    }
}

public enum NiveauNotification: String, Codable, Sendable {
    case info, important, alerte
}

public struct NotificationRelais: Codable, Sendable, Identifiable, Equatable {
    public let seq: Int
    public let sessionId: String?
    public let niveau: NiveauNotification
    public let titre: String
    public let texte: String
    public let ts: String
    public let lue: Bool

    public var id: Int { seq }
}

public struct EtatRelais: Decodable, Sendable {
    public let version: Int
    public let machines: [Machine]
    public let sessions: [Session]
    public let notifications: [NotificationRelais]
    public let reveilPossible: [String]
}

/// Réponse du long-poll `/api/attente` : rendue dès que la version du relais dépasse la connue, ou à l'échéance.
public struct ReponseAttente: Decodable, Sendable {
    public let version: Int
    public let notifications: [NotificationRelais]
    public let sessions: [Session]
    public let machines: [Machine]
}

/// Ouverture d'une session. `mode`, `effort` et `ultracode` sont omis du JSON quand ils ne sont pas posés.
public struct DemandeOuverture: Encodable, Sendable {
    public let machine: String
    public let projet: Projet
    public let message: String
    public let titre: String?
    public let objectif: String?
    public let autonomie: Bool
    public let modele: String?
    public let mode: String?
    public let effort: String?
    public let ultracode: Bool?
    /// Pièces jointes au premier message (omises quand il n'y en a pas).
    public var pieces: [PieceJointe]?

    public init(machine: String, projet: Projet, message: String, titre: String?, objectif: String?,
                autonomie: Bool, modele: String?, mode: String? = nil, effort: String? = nil, ultracode: Bool? = nil) {
        self.machine = machine
        self.projet = projet
        self.message = message
        self.titre = titre
        self.objectif = objectif
        self.autonomie = autonomie
        self.modele = modele
        self.mode = mode
        self.effort = effort
        self.ultracode = ultracode
        self.pieces = nil
    }
}

/// Actions sur une session : `marquerLue` et `marquerNonLue` sont des routes à part entière (`marquer_lue`).
public enum ActionSession: String, Sendable {
    case interrompre, compacter, fermer, reprendre
    case archiver, desarchiver, epingler, desepingler
    case marquerLue = "marquer_lue", marquerNonLue = "marquer_non_lue"
}
