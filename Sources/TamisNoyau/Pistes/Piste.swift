// Les pistes : les familles de clichés qu'on peut presque toujours retirer sans
// regret. Chaque piste propose, jamais ne décide — rien n'entre au panier sans
// un geste.
import Foundation

public enum Piste: String, Sendable, CaseIterable, Hashable, Identifiable {
    case doublons, similaires, rafales, videosLourdes, captures, utilitaires, ratees, videosFurtives

    public var id: String { rawValue }

    /// Vrai si la piste se revoit groupe par groupe (on garde un élu par groupe).
    public var parGroupes: Bool {
        switch self {
        case .doublons, .similaires, .rafales: return true
        default: return false
        }
    }
}

/// Ce qu'une piste a trouvé.
public struct Releve: Sendable, Hashable, Identifiable {
    public let piste: Piste
    /// Pour les pistes par groupes ; vide sinon.
    public let groupes: [[String]]
    /// Ce qu'on propose de retirer, du plus ancien au plus récent.
    public let proposes: [String]
    public let poids: Int64

    public var id: Piste { piste }
}

/// Les réglages de la recherche de pistes. Les seuils Vision sont des
/// estimations : aucun n'est étalonné, d'où leur exposition à l'écran.
public struct ReglagePistes: Sendable, Hashable {
    public var seuilSimilarite: Float = 0.92
    public var scoreRatee: Float = -0.25
    public var videoLourde: Int64 = 200_000_000
    public var videoFurtive: Double = 3

    public init() {}
}
