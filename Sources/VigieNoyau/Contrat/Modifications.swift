import Foundation

// Responsabilité : un fichier touché par un tour (miroir de `FichierModifie` dans `commun/modifications.ts`).

public struct FichierModifie: Codable, Sendable, Equatable {
    public let chemin: String
    /// `ajoute`, `modifie` ou `supprime`.
    public let etat: String
    public let ajouts: Int
    public let suppressions: Int
    public let binaire: Bool

    public init(chemin: String, etat: String, ajouts: Int, suppressions: Int, binaire: Bool) {
        self.chemin = chemin
        self.etat = etat
        self.ajouts = ajouts
        self.suppressions = suppressions
        self.binaire = binaire
    }

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: CodingKeys.self)
        chemin = try c.decode(String.self, forKey: .chemin)
        etat = try c.decode(String.self, forKey: .etat)
        ajouts = try c.entier(.ajouts)
        suppressions = try c.entier(.suppressions)
        binaire = try c.decode(Bool.self, forKey: .binaire)
    }
}
