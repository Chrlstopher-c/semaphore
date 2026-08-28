// L'état sémantique de la charte. Un écran ne choisit jamais une couleur : il
// choisit un ton, et le ton se traduit ici — une seule fois, pour tout le monde.
#if canImport(SwiftUI)
import SwiftUI

public enum Ton: Sendable, Hashable, CaseIterable {
    /// Ce qui est interactif, la synchro vivante. Le seul ton qui porte l'accent.
    case actif
    /// Item synchronisé, serveur joignable.
    case ok
    /// Récupérable : hors ligne, capture en attente, téléversement lent.
    case alerte
    /// Échec réel, geste destructif.
    case panne
    /// Le régime ordinaire : la très grande majorité du monde.
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

    /// Le fond voilé d'un sceau de ce ton. 15 % : assez pour se détacher de la
    /// surface, trop peu pour devenir une tache de couleur.
    public var voile: Color { couleur.opacity(0.15) }
}
#endif
