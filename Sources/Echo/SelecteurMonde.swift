#if canImport(SwiftUI)
import SwiftUI
import Systeme

/// Le sélecteur de monde : une ligne en tête, un filet dessous. Peint avec le
/// socle, en pierre — c'est le seul élément du centre qui n'appartient à aucun
/// monde, et il ne doit jamais en prendre la couleur au repos. Seul
/// l'indicateur du monde actif laisse transparaître l'accent du monde pointé,
/// par son glyphe — pas d'aplat.
struct SelecteurMonde: View {
    @Binding var monde: Monde
    /// La bascule appartient au pupitre : c'est lui qui joue l'animation de
    /// monde et le retour haptique, en un seul endroit.
    let bascule: (Monde) -> Void

    var body: some View {
        HStack(spacing: Grille.serre) {
            ForEach(Monde.allCases) { candidat in
                bouton(candidat)
            }
        }
        .padding(.horizontal, Grille.ecran)
        .padding(.vertical, Grille.fin)
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Neutre.trait)
                .frame(height: Grille.trait)
        }
        .background(Neutre.fond)
    }

    private func bouton(_ candidat: Monde) -> some View {
        let actif = candidat == monde
        return Button {
            bascule(candidat)
        } label: {
            HStack(spacing: Grille.fin) {
                Image(systemName: candidat.symbole)
                    .font(Voix.legende)
                    .foregroundStyle(actif ? TeinteEcho.accent(du: candidat) : Neutre.encreEteinte)
                Text(candidat.titre)
                    .font(Voix.legende)
                    .fontWeight(actif ? .semibold : .medium)
                    .foregroundStyle(actif ? Neutre.encre : Neutre.encreEteinte)
            }
            .padding(.horizontal, Grille.element)
            .padding(.vertical, Grille.fin)
            .background(actif ? Neutre.surface : .clear, in: Capsule())
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(candidat.titre)
        .accessibilityAddTraits(actif ? .isSelected : [])
    }
}
#endif
