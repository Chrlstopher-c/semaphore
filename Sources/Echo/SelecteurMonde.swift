#if canImport(SwiftUI)
import SwiftUI
import Vigie

/// Le sélecteur de monde : une ligne en tête, deux entrées, un filet dessous.
/// Écrit à la main comme la barre de veille de Vigie, avec ses jetons — c'est
/// le seul élément du centre qui n'appartient à aucun des deux mondes.
struct SelecteurMonde: View {
    @Binding var monde: Monde

    var body: some View {
        HStack(spacing: Vigie.Trame.serre) {
            ForEach(Monde.allCases) { candidat in
                bouton(candidat)
            }
        }
        .padding(.horizontal, Vigie.Trame.ecran)
        .padding(.vertical, Vigie.Trame.fin)
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) { Vigie.FiletFin() }
        .background(Vigie.Teinte.fond)
        .sensoryFeedback(Vigie.Haptique.selection, trigger: monde)
    }

    private func bouton(_ candidat: Monde) -> some View {
        let actif = candidat == monde
        return Button {
            guard !actif else { return }
            withAnimation(Vigie.Elan.vif) { monde = candidat }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: candidat.symbole)
                    .font(.system(size: 12, weight: actif ? .semibold : .regular))
                Text(candidat.titre)
                    .font(.system(size: 12, weight: actif ? .semibold : .medium))
            }
            .foregroundStyle(actif ? Vigie.Teinte.accent : Vigie.Teinte.encreTernie)
            .padding(.horizontal, Vigie.Trame.serre + 2)
            .padding(.vertical, 5)
            .background(actif ? Vigie.Teinte.surface : .clear, in: Capsule())
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(candidat.titre)
        .accessibilityAddTraits(actif ? .isSelected : [])
    }
}
#endif
