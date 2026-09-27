// Le filtre combiné : une période, des natures, un poids plancher. C'est la
// seule règle qui décide si un cliché « passe au tamis ».
import Foundation

public struct Tamisage: Sendable, Hashable {
    public var plage: PlageDates
    /// Vide = tous les médias.
    public var medias: Set<Media>
    /// Le cliché doit porter AU MOINS un de ces traits. Vide = aucune exigence.
    public var traits: Set<Trait>
    public var poidsMin: Int64?
    /// Vrai par défaut : un favori est une décision déjà prise par Chris.
    public var epargnerFavoris: Bool

    public init(
        plage: PlageDates = .tout, medias: Set<Media> = [], traits: Set<Trait> = [],
        poidsMin: Int64? = nil, epargnerFavoris: Bool = true
    ) {
        self.plage = plage
        self.medias = medias
        self.traits = traits
        self.poidsMin = poidsMin
        self.epargnerFavoris = epargnerFavoris
    }

    public func retient(_ cliche: Cliche) -> Bool {
        if epargnerFavoris, cliche.estFavori { return false }
        guard plage.contient(cliche.date) else { return false }
        if !medias.isEmpty, !medias.contains(cliche.media) { return false }
        if !traits.isEmpty, traits.isDisjoint(with: cliche.traits) { return false }
        if let poidsMin {
            guard let poids = cliche.poids, poids >= poidsMin else { return false }
        }
        return true
    }

    /// Les retenus, du plus ancien au plus récent, les sans-date à la fin.
    public func passer(_ cliches: [Cliche]) -> [Cliche] {
        cliches.filter(retient).sorted(by: Tamisage.chronologique)
    }

    public static func chronologique(_ a: Cliche, _ b: Cliche) -> Bool {
        switch (a.date, b.date) {
        case let (da?, db?): return da < db
        case (nil, _?): return false
        case (_?, nil): return true
        case (nil, nil): return a.id < b.id
        }
    }
}
