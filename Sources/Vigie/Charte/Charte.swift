// La charte de Vigie : iOS natif (couleurs et typographie du système, listes groupées, barres natives) avec la seule
// teinte Echo Agency — brand-600 en clair, brand-400 en night — posée comme `tint`. Vigie suit le mode de l'iPhone.
#if canImport(SwiftUI)
import SwiftUI
import UIKit
import VigieNoyau

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

enum Charte {
    /// L'accent Echo Agency, qui change avec le mode : brand-600 (#7D48B5) en clair, brand-400 (#A774D4) en night.
    static let accent = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: 0xA774D4) : UIColor(hex: 0x7D48B5)
    })

    /// L'état d'une session : l'accent quand elle travaille, les couleurs système sinon.
    static func couleur(_ statut: StatutSession) -> Color {
        switch statut {
        case .demarrage, .travail, .compaction: return accent
        case .attente, .terminee: return .green
        case .question: return .orange
        case .erreur: return .red
        case .fermee: return Color(.tertiaryLabel)
        }
    }

    static func symbole(_ outil: String) -> String {
        switch outil {
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Edit", "Write": return "pencil"
        case "Grep", "Glob": return "magnifyingglass"
        case "WebFetch", "WebSearch": return "globe"
        case "Agent", "Task": return "sparkles"
        default: return "wrench.and.screwdriver"
        }
    }
}

/// L'accent de Vigie vu par le pupitre (chrome toujours sombre) : brand-400.
public enum Teinte {
    public static let accent = Color(hex: 0xA774D4)
}

/// Point d'état d'une session : pulse tant qu'elle travaille.
struct PointEtat: View {
    let statut: StatutSession

    var body: some View {
        Circle().fill(Charte.couleur(statut)).frame(width: 9, height: 9)
            .phaseAnimator(statut.enActivite ? [1.0, 0.35] : [1.0]) { vue, phase in vue.opacity(phase) }
                animation: { _ in .easeInOut(duration: 0.9) }
            .accessibilityLabel(statut.libelle)
    }
}
#endif
