// L'état sémantique : un écran choisit un ton, jamais une couleur.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Ton: Sendable, Hashable, CaseIterable {
    /// Interactif, gardé.
    case actif
    /// Au panier, supprimé.
    case depart
    case ok
    case alerte
    case neutre

    public var couleur: Color {
        switch self {
        case .actif: return Teinte.accent
        case .depart: return Teinte.depart
        case .ok: return Semantique.ok
        case .alerte: return Semantique.alerte
        case .neutre: return Neutre.encreDouce
        }
    }

    /// Le fond voilé d'un sceau ou d'un bandeau : 15 %.
    public var voile: Color { couleur.opacity(0.15) }
}
#endif
