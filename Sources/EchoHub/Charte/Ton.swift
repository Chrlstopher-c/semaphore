// L'état sémantique de la charte. Un écran ne choisit jamais une couleur : il
// choisit un ton, et le ton se traduit ici — une seule fois, pour toute l'app.
#if canImport(SwiftUI)
import SwiftUI

public enum Ton: Sendable, Hashable, CaseIterable {
    /// Ce qui génère, ce qui est interactif. Le seul ton qui porte l'accent.
    case actif
    /// Modèle prêt, relais joignable, outil abouti.
    case ok
    /// Récupérable : interrompu, dégradé, coupé au plafond de tokens.
    case alerte
    /// Échec réel, geste destructif.
    case panne
    /// Le régime ordinaire : la très grande majorité de l'app.
    case neutre

    public var couleur: Color {
        switch self {
        case .actif: return Teinte.accent
        case .ok: return Teinte.ok
        case .alerte: return Teinte.alerte
        case .panne: return Teinte.panne
        case .neutre: return Teinte.encreDouce
        }
    }

    /// Le fond voilé d'un sceau de ce ton. 14 % : assez pour se détacher de la
    /// surface, trop peu pour devenir une tache de couleur.
    public var voile: Color { couleur.opacity(0.14) }
}
#endif
