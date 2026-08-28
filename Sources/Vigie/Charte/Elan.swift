// Le mouvement de la charte : trois ressorts, une cascade, et deux règles.
// Bouge : l'arrivée d'un élément NOUVEAU, un changement d'état, le retour
// d'appui. Ne bouge jamais : un rafraîchissement périodique, le texte lu, la
// position de défilement.
#if canImport(SwiftUI)
import SwiftUI

public enum Elan {
    /// Retour d'appui, bascules, sélection.
    public static let vif = Animation.spring(response: 0.26, dampingFraction: 0.88)
    /// Changements d'état, plis et déplis.
    public static let pose = Animation.spring(response: 0.40, dampingFraction: 0.86)
    /// Arrivée d'un élément nouveau.
    public static let entree = Animation.spring(response: 0.55, dampingFraction: 0.82)

    /// `entree` retardée de 45 ms par rang, plafonnée : le douzième élément
    /// d'une longue liste n'attend pas une seconde pour exister.
    public static func cascade(_ rang: Int) -> Animation {
        entree.delay(Double(min(max(rang, 0), 6)) * 0.045)
    }
}

extension View {
    /// Entrée en scène d'un élément nouveau : fondu + léger soulèvement.
    ///
    /// `☠` À poser sur des vues à IDENTITÉ STABLE seulement : sur une liste
    /// dont les identifiants changent à chaque relevé, chaque battement
    /// rejouerait l'entrée — c'est le clignotement qu'on interdit.
    public func entreeEnScene(rang: Int = 0) -> some View {
        modifier(EntreeEnScene(rang: rang))
    }
}

private struct EntreeEnScene: ViewModifier {
    let rang: Int
    @State private var posee = false

    func body(content: Content) -> some View {
        content
            .opacity(posee ? 1 : 0)
            .offset(y: posee ? 0 : 10)
            .onAppear {
                withAnimation(Elan.cascade(rang)) { posee = true }
            }
    }
}

/// Trois points qui respirent — « quelque chose est en train de se produire ».
/// Réservé à un travail réellement en vol (génération, résultat attendu).
public struct SouffleActivite: View {
    let teinte: Color
    @State private var phase = false

    public init(teinte: Color = Teinte.encreTernie) {
        self.teinte = teinte
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { rang in
                Circle()
                    .fill(teinte)
                    .frame(width: 4, height: 4)
                    .opacity(phase ? 1 : 0.25)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(rang) * 0.16),
                        value: phase
                    )
            }
        }
        .onAppear { phase = true }
    }
}
#endif
