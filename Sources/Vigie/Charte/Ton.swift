// L'état sémantique de la charte : six tons, et c'est par eux que passe toute
// couleur d'état. Un écran ne choisit jamais une couleur, il choisit un ton.
#if canImport(SwiftUI)
import SwiftUI

public enum Ton: Sendable, Hashable {
    /// La main de Chris est requise. Le seul ton qui porte l'orange.
    case attention
    case sain
    case vigilance
    case danger
    /// Le calme : PC éteint, pause, repos. Un état normal, pas une panne.
    case veille
    case neutre

    public var teinte: Color {
        switch self {
        case .attention: return Teinte.accent
        case .sain: return Teinte.sain
        case .vigilance: return Teinte.vigilance
        case .danger: return Teinte.danger
        case .veille: return Teinte.veille
        case .neutre: return Teinte.encreTernie
        }
    }

    /// Le fond voilé d'un encart de ce ton. Le texte posé dessus est `teinte` :
    /// les sémantiques sont calibrées lisibles sur sombre.
    public var voile: Color { teinte.opacity(0.14) }
}
#endif
