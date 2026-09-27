// L'empreinte visuelle d'une photo : le vecteur que rend Vision, normalisé une
// fois pour toutes. Comparer deux photos se réduit alors à un produit scalaire.
import Foundation

public struct Empreinte: Sendable {
    public let id: String
    public let date: Date
    public let vecteur: [Float]

    /// `nil` si le vecteur est vide ou nul : il ne ressemblerait à rien.
    public init?(id: String, date: Date, brut: [Float]) {
        let norme = brut.reduce(Float(0)) { $0 + $1 * $1 }.squareRoot()
        guard norme > 0 else { return nil }
        self.id = id
        self.date = date
        self.vecteur = brut.map { $0 / norme }
    }

    /// Cosinus entre deux empreintes, dans [-1, 1]. 1 = même image.
    public func similarite(_ autre: Empreinte) -> Float {
        guard vecteur.count == autre.vecteur.count else { return -1 }
        var somme: Float = 0
        for i in vecteur.indices { somme += vecteur[i] * autre.vecteur[i] }
        return somme
    }
}

/// Deux photos jugées proches, et à quel point. Seule trace gardée de l'analyse :
/// les vecteurs eux-mêmes pèseraient 3 Ko par photo, soit 100 Mo pour la
/// photothèque — les paires, quelques centaines de Ko.
public struct Paire: Codable, Sendable, Hashable {
    public let a: String
    public let b: String
    public let similarite: Float

    public init(a: String, b: String, similarite: Float) {
        self.a = a
        self.b = b
        self.similarite = similarite
    }
}
