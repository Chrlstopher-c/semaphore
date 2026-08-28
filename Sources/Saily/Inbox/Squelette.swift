// Le chargement de la besace : des cartes FANTÔMES plutôt qu'un tourniquet.
// L'écran raconte la FORME de ce qui arrive — une liste de cartes — au lieu de
// montrer un vide et de faire deviner. Marqueur « fini » le plus rentable au
// chargement (NN/g : réduit l'incertitude et le temps perçu).
//
// `☠` Seule l'OPACITÉ respire, jamais la mise en page — conforme à la charte
// (« seuls transform et opacity s'animent »). Et le pouls s'éteint sous
// « Réduire les animations » : un squelette qui bat est aussi du mouvement.
#if canImport(SwiftUI)
import SwiftUI

struct SqueletteInbox: View {
    var body: some View {
        VStack(spacing: Trame.element) {
            ForEach(0..<5, id: \.self) { rang in
                SqueletteCarte(rang: rang)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Trame.ecran)
        .padding(.vertical, Trame.element)
        .accessibilityLabel("Chargement de la besace")
    }
}

private struct SqueletteCarte: View {
    let rang: Int
    @Environment(\.accessibilityReduceMotion) private var reduireMouvement
    @State private var respire = false

    /// Dimensions du fantôme, HORS grille `Trame` : un rectangle qui ne
    /// représente rien de réel n'a pas de jeton d'espacement dédié.
    private let coteVignette: CGFloat = Trame.vignette
    private let hauteurLigne: CGFloat = 12

    var body: some View {
        Panneau {
            HStack(alignment: .top, spacing: Trame.element) {
                bloc(largeur: coteVignette, hauteur: coteVignette)
                VStack(alignment: .leading, spacing: Trame.serre) {
                    bloc(largeur: 90, hauteur: hauteurLigne)
                    bloc(largeur: .infinity, hauteur: hauteurLigne)
                    bloc(largeur: 200, hauteur: hauteurLigne)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .opacity(reduireMouvement ? 0.5 : (respire ? 0.4 : 0.85))
        .onAppear { lancerLePouls() }
    }

    private func bloc(largeur: CGFloat, hauteur: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Trame.fin, style: .continuous)
            .fill(Teinte.surfaceHaute)
            .frame(maxWidth: largeur == .infinity ? .infinity : nil)
            .frame(width: largeur == .infinity ? nil : largeur, height: hauteur)
    }

    private func lancerLePouls() {
        guard !reduireMouvement else { return }
        withAnimation(
            .easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(Double(rang) * 0.08)
        ) {
            respire = true
        }
    }
}
#endif
