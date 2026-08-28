// La barre de veille : cinq domaines, écrite à la main — `TabView` replie tout
// ce qui dépasse cinq onglets derrière un « Plus » hors charte.
//
// Le badge du Quart est le seul ornement : un mandat en attente doit se voir
// depuis n'importe quel onglet, la nuit, sans lunettes.
#if canImport(SwiftUI)
import SwiftUI

struct BarreDeVeille: View {
    @Binding var onglet: Domaine
    let decisions: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Domaine.barre) { domaine in
                bouton(domaine)
            }
        }
        .padding(.top, Trame.serre - 2)
        .padding(.horizontal, Trame.serre)
        .background(alignment: .top) { FiletFin() }
        .background(Teinte.fond)
        .sensoryFeedback(Haptique.selection, trigger: onglet)
    }

    private func bouton(_ domaine: Domaine) -> some View {
        let actif = domaine == onglet
        return Button {
            guard !actif else { return }
            withAnimation(Elan.vif) { onglet = domaine }
        } label: {
            VStack(spacing: 3) {
                symbole(domaine, actif: actif)
                Text(domaine.titre)
                    .font(.system(size: 9.5, weight: actif ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(actif ? Teinte.accent : Teinte.encreTernie)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Trame.fin + 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(domaine.titre)
        .accessibilityAddTraits(actif ? .isSelected : [])
    }

    private func symbole(_ domaine: Domaine, actif: Bool) -> some View {
        Image(systemName: domaine.symbole)
            .font(.system(size: 17, weight: actif ? .semibold : .regular))
            .symbolEffect(.bounce, value: actif)
            .frame(height: 20)
            .overlay(alignment: .topTrailing) {
                if domaine == .quart, decisions > 0 { pastille }
            }
    }

    /// Le compte de ce qui attend, en orange — le seul chiffre de la barre.
    private var pastille: some View {
        Text("\(min(decisions, 99))")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(Teinte.encreSurAccent)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Teinte.accent, in: Capsule())
            .offset(x: 12, y: -5)
            .transition(.scale.combined(with: .opacity))
            .animation(Elan.vif, value: decisions)
    }
}
#endif
