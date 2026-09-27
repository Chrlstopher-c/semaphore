// Ce que le tri rapide fait défiler. Quatre files, chacune ordonnée pour que le
// plus rentable passe d'abord.
#if canImport(SwiftUI) && canImport(Photos)
import TamisNoyau

enum SourceTri: CaseIterable, Hashable {
    case anciennes, lourdes, captures, videos

    var libelle: String {
        switch self {
        case .anciennes: return "Anciennes"
        case .lourdes: return "Lourdes"
        case .captures: return "Captures"
        case .videos: return "Vidéos"
        }
    }

    /// La file, sans ce qui a déjà un verdict ni les favoris.
    func file(_ cliches: [Cliche], decides: Set<String>) -> [String] {
        let libres = cliches.filter { !decides.contains($0.id) && !$0.estFavori }
        switch self {
        case .anciennes:
            return libres.sorted(by: Tamisage.chronologique).map(\.id)
        case .lourdes:
            return parPoids(libres)
        case .captures:
            return libres.filter { $0.traits.contains(.capture) }.sorted(by: Tamisage.chronologique).map(\.id)
        case .videos:
            return parPoids(libres.filter { $0.media == .video })
        }
    }

    private func parPoids(_ cliches: [Cliche]) -> [String] {
        cliches.sorted { ($0.poids ?? 0) > ($1.poids ?? 0) }.map(\.id)
    }
}
#endif
