import Foundation

// Responsabilité : le vocabulaire du panneau de session — contexte, tâches de fond et environnements, tels que le
// relais les rend (miroir de `commun/panneau.ts`).

public struct CategorieContexte: Codable, Sendable, Equatable {
    public let id: String
    public let libelle: String
    public let jetons: Int
    /// `utilise`, `libre`, `tampon` ou `differe`.
    public let genre: String
}

public struct OutilMcp: Codable, Sendable, Equatable {
    public let serveur: String
    public let outil: String
    public let jetons: Int
    /// Outil chargé à la demande : il ne pèse pas encore dans l'utilisé.
    public let differe: Bool
}

public struct ContexteSession: Codable, Sendable, Equatable {
    public let modele: String
    public let fenetre: Int
    public let utilises: Int
    public let pourcentage: Double
    public let categories: [CategorieContexte]
    public let categoriesDifferees: [CategorieContexte]
    public let outilsMcp: [OutilMcp]
}

public struct TacheSession: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let type: String
    public let description: String
    /// Valeur brute du SDK : `en_attente`, `en_cours`, `pausee`, `terminee`, `echouee`, `arretee`.
    public let statut: String
    public let arrierePlan: Bool
    public let sousAgent: String?
    public let modele: String?
    public let activite: String?
    public let outils: Int
    public let jetons: Int
    public let dureeMs: Int
    public let debutLe: String
    public let finLe: String?
}

/// Un dossier d'une machine où ouvrir une session, et s'il est enregistré comme projet.
public struct Environnement: Codable, Sendable, Equatable {
    public let machine: String
    public let dossier: String
    public let enregistre: Bool
}
