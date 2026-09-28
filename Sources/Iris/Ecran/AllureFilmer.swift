// Le bouton du monde : aplat d'accent au repos, trait d'alerte quand le flux part.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

struct AllureFilmer: ButtonStyle {
    let enDirect: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Voix.entete)
            .frame(maxWidth: .infinity, minHeight: Trame.bouton)
            .foregroundStyle(enDirect ? Semantique.panne : Teinte.encreSurAccent)
            .background(
                fond(presse: configuration.isPressed),
                in: .rect(cornerRadius: Rayon.controle, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous)
                    .strokeBorder(enDirect ? Neutre.trait : .clear, lineWidth: Grille.trait)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Mouvement.micro, value: configuration.isPressed)
    }

    private func fond(presse: Bool) -> Color {
        if enDirect { return presse ? Neutre.surfaceHaute : Neutre.surface }
        return presse ? Teinte.accentPresse : Teinte.accent
    }
}
#endif
