// Dans un groupe de photos semblables, celle qu'on garde. L'ordre des critères
// est la règle : ce que Chris a déjà choisi, puis ce que Vision juge meilleur,
// puis la définition, puis le poids — jamais l'inverse.
import Foundation

/// Le jugement de Vision sur une photo.
public struct Qualite: Codable, Sendable, Hashable {
    /// Score esthétique global, de -1 (ratée) à 1.
    public let score: Float
    /// Document, reçu, capture, QR : une image utilitaire plutôt qu'un souvenir.
    public let utilitaire: Bool

    public init(score: Float, utilitaire: Bool) {
        self.score = score
        self.utilitaire = utilitaire
    }
}

public enum Election {
    public static func meilleur(
        _ ids: [String], cliches: [String: Cliche], qualites: [String: Qualite], gardes: Set<String> = []
    ) -> String? {
        ids.max { rang($0, cliches, qualites, gardes) < rang($1, cliches, qualites, gardes) }
    }

    /// Le reste du groupe : ce qu'on propose de retirer.
    public static func surplus(
        _ ids: [String], cliches: [String: Cliche], qualites: [String: Qualite], gardes: Set<String> = []
    ) -> [String] {
        guard let elu = meilleur(ids, cliches: cliches, qualites: qualites, gardes: gardes) else { return [] }
        return ids.filter { $0 != elu && !gardes.contains($0) && !(cliches[$0]?.estFavori ?? false) }
    }

    private struct Rang: Comparable {
        let choisi: Int, score: Float, pixels: Int, poids: Int64, id: String
        static func < (a: Rang, b: Rang) -> Bool {
            (a.choisi, a.score, a.pixels, a.poids, b.id) < (b.choisi, b.score, b.pixels, b.poids, a.id)
        }
    }

    private static func rang(
        _ id: String, _ cliches: [String: Cliche], _ qualites: [String: Qualite], _ gardes: Set<String>
    ) -> Rang {
        let c = cliches[id]
        let traits = c?.traits ?? []
        let choisi = (gardes.contains(id) || traits.contains(.favori) ? 2 : 0) + (traits.contains(.choixRafale) ? 1 : 0)
        return Rang(
            choisi: choisi, score: qualites[id]?.score ?? -2,
            pixels: c?.pixels ?? 0, poids: c?.poids ?? 0, id: id
        )
    }
}
