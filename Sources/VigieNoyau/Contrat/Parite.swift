import Foundation

// Responsabilité : le vocabulaire de la parité d'une session — tâches de fond tirées du transcript sur le poste,
// pour une session lancée hors de Lanterne ou suivie en Remote Control. Miroir de `commun/parite.ts` (relais).

/// Genre d'une tâche de fond : sous-agent (`agent`) ou commande d'arrière-plan (`commande`).
public enum GenreTache: String, Codable, Sendable, Equatable {
    case agent, commande
}

public enum StatutTacheParite: String, Codable, Sendable, Equatable {
    case enCours = "en_cours", terminee, echouee, arretee
}

/// Une tâche lancée en arrière-plan. Une valeur mal formée fait écarter la tâche, pas le tableau entier.
public struct TacheParite: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let genre: GenreTache
    public let description: String
    public let statut: StatutTacheParite
    public let debutLe: String
    public let finLe: String?
    public let modele: String?
}

/// Détail d'une tâche : les champs de la tâche, plus la consigne (agent ou commande) et la fin de son activité.
public struct DetailTacheParite: Decodable, Sendable, Equatable {
    public let tache: TacheParite
    public let prompt: String?
    public let activite: String?

    public init(from decodeur: Decoder) throws {
        tache = try TacheParite(from: decodeur)
        let c = try decodeur.container(keyedBy: CodingKeys.self)
        prompt = c.facultatif(String.self, .prompt)
        activite = c.facultatif(String.self, .activite)
    }

    private enum CodingKeys: String, CodingKey {
        case prompt, activite
    }
}

/// La parité d'une session : `transcript` à faux quand aucun transcript n'est lisible (session claude.ai sans poste).
public struct PariteSession: Decodable, Sendable, Equatable {
    public let transcript: Bool
    /// Plus récente d'abord. Une tâche mal formée est écartée, les autres restent.
    public let taches: [TacheParite]

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: CodingKeys.self)
        transcript = try c.decode(Bool.self, forKey: .transcript)
        let lues = c.facultatif([Tolere<TacheParite>].self, .taches) ?? []
        taches = lues.compactMap(\.valeur)
    }

    private enum CodingKeys: String, CodingKey {
        case transcript, taches
    }
}
