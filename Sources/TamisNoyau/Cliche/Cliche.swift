// Ce que Tamis sait d'un élément de la photothèque, sans PhotoKit. Tout le noyau
// raisonne sur cette fiche : elle se construit sur l'iPhone, se teste sur Linux.
import Foundation

public enum Media: String, Codable, Sendable, CaseIterable, Hashable {
    case photo, video
}

/// Les particularités qui orientent le tri. Un cliché peut en cumuler plusieurs.
public enum Trait: String, Codable, Sendable, CaseIterable, Hashable {
    case capture, live, rafale, panorama, favori
    /// Photo principale d'une rafale : celle que Photos montre par défaut.
    case choixRafale
}

public struct Cliche: Sendable, Hashable, Identifiable {
    /// `localIdentifier` de PhotoKit.
    public let id: String
    public let date: Date?
    public let media: Media
    public let traits: Set<Trait>
    public let largeur: Int
    public let hauteur: Int
    /// En secondes, nul pour une photo.
    public let duree: Double
    /// Rafale d'appartenance, nulle hors rafale.
    public let rafale: String?
    /// En octets, somme des ressources originales. Nul tant que la pesée n'a
    /// pas eu lieu : un poids inconnu n'est jamais compté pour zéro en silence.
    public var poids: Int64?

    public init(
        id: String, date: Date?, media: Media, traits: Set<Trait> = [],
        largeur: Int = 0, hauteur: Int = 0, duree: Double = 0,
        rafale: String? = nil, poids: Int64? = nil
    ) {
        self.id = id
        self.date = date
        self.media = media
        self.traits = traits
        self.largeur = largeur
        self.hauteur = hauteur
        self.duree = duree
        self.rafale = rafale
        self.poids = poids
    }

    public var pixels: Int { largeur * hauteur }
    public var estFavori: Bool { traits.contains(.favori) }
}

extension Sequence where Element == Cliche {
    /// Somme des poids connus. Les inconnus sont comptés à part par l'appelant.
    public var poidsTotal: Int64 { reduce(0) { $0 + ($1.poids ?? 0) } }
}
