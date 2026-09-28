import Foundation

// Le parc, les notifications et l'état global, tels que le relais les rend (miroir de `commun/api-clients.ts`).

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

public struct Machine: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let description: String
    public let racines: [String]
    public let projets: [Projet]
    public let comptes: [String]
    public let version: String
    public let etat: EtatMachine?
    public let derniereVue: String
    public let enLigne: Bool
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

/// Réponse du long-poll `/api/attente` : rendue dès que la version du relais dépasse celle connue, ou à l'échéance.
public struct ReponseAttente: Decodable, Sendable {
    public let version: Int
    public let notifications: [NotificationRelais]
    public let sessions: [Session]
    public let machines: [Machine]
}

public struct DemandeOuverture: Encodable, Sendable {
    public let machine: String
    public let projet: Projet
    public let message: String
    public let titre: String?
    public let objectif: String?
    public let autonomie: Bool
    public let modele: String?

    public init(machine: String, projet: Projet, message: String, titre: String?, objectif: String?,
                autonomie: Bool, modele: String?) {
        self.machine = machine
        self.projet = projet
        self.message = message
        self.titre = titre
        self.objectif = objectif
        self.autonomie = autonomie
        self.modele = modele
    }
}

public enum ActionSession: String, Sendable {
    case interrompre, compacter, fermer, reprendre
}
