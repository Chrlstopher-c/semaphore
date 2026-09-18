// L'état sémantique de la charte. Un écran ne choisit jamais une couleur : il
// choisit un ton, et le ton se traduit ici — une seule fois, pour tout le monde.
//
// `☠` Pas d'`Ambiance` ni de `Palier` comme chez Saily : Duplex n'emboîte jamais
// une carte dans une carte, un système de profondeur serait un jeton sans emploi.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Ton: Sendable, Hashable, CaseIterable {
    /// Ce qui est interactif, le son qui coule. Le seul ton qui porte l'accent.
    case actif
    /// Liaison établie, flux sain.
    case ok
    /// Récupérable : code refusé, tampon qui se refait, coupures comptées.
    case alerte
    /// Échec réel : PC injoignable, jumelage refusé.
    case panne
    /// Le régime ordinaire : la très grande majorité du monde.
    case neutre

    public var couleur: Color {
        switch self {
        case .actif: return Teinte.accent
        case .ok: return Semantique.ok
        case .alerte: return Semantique.alerte
        case .panne: return Semantique.panne
        case .neutre: return Neutre.encreDouce
        }
    }

    /// Le fond voilé d'un sceau ou d'un bandeau de ce ton. 15 % : assez pour se
    /// détacher de la surface, trop peu pour devenir une tache de couleur.
    public var voile: Color { couleur.opacity(0.15) }
}
#endif
