#if canImport(SwiftUI)
import SwiftUI
import Systeme

/// La barre du pupitre : le monde actif, et rien d'autre. Toucher son nom ouvre
/// la grille des mondes.
///
/// `☠` Une rangée de pilules ne tient pas au-delà de quatre mondes sur 335 pt :
/// les libellés se tassent, puis se coupent. La barre ne montre donc plus que le
/// monde devant soi — le choix vit dans la grille, qui accueille dix mondes sans
/// changer de forme.
///
/// Peinte avec le socle, en pierre : le seul élément du centre qui n'appartient
/// à aucun monde. Seul le glyphe du monde actif laisse passer son accent.
struct SelecteurMonde: View {
    let monde: Monde
    @Binding var ouverte: Bool
    @Environment(\.accessibilityReduceMotion) private var reduireMouvement

    var body: some View {
        HStack(spacing: Grille.serre) {
            Button(action: basculer) {
                HStack(spacing: Grille.serre) {
                    Image(systemName: monde.symbole)
                        .foregroundStyle(TeinteEcho.accent(du: monde))
                        .contentTransition(.symbolEffect(.replace))
                    Text(monde.titre)
                        .foregroundStyle(Neutre.encre)
                        .contentTransition(.opacity)
                    Image(systemName: "chevron.down")
                        .font(Voix.legende)
                        .foregroundStyle(Neutre.encreEteinte)
                        .rotationEffect(.degrees(ouverte ? 180 : 0))
                }
                .font(Voix.entete)
                .frame(minHeight: Grille.cible)
                .contentShape(.rect)
            }
            .buttonStyle(AppuiPupitre())
            .accessibilityLabel("Monde : \(monde.titre). Changer de monde")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Grille.ecran)
        .background(alignment: .bottom) {
            Rectangle().fill(Neutre.trait).frame(height: Grille.trait)
        }
        .background(Neutre.fond)
        .sensoryFeedback(Toucher.contact, trigger: ouverte)
    }

    private func basculer() {
        withAnimation(reduireMouvement ? Mouvement.fonduReduit : Mouvement.normal) {
            ouverte.toggle()
        }
    }
}

/// La grille des mondes, déroulée sous la barre par-dessus le monde actif, qui
/// s'assombrit sans disparaître : on sait d'où l'on part.
struct GrilleMondes: View {
    let monde: Monde
    let fermer: () -> Void
    /// La bascule appartient au pupitre : animation de monde et retour haptique
    /// en un seul endroit.
    let bascule: (Monde) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduireMouvement
    @State private var posee = false

    private let colonnes = Array(repeating: GridItem(.flexible(), spacing: Grille.serre), count: 3)

    var body: some View {
        ZStack(alignment: .top) {
            Neutre.fond.opacity(0.72)
                .ignoresSafeArea(edges: .bottom)
                .onTapGesture(perform: fermer)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Fermer")
            panneau
        }
        .transition(.opacity)
    }

    private var panneau: some View {
        LazyVGrid(columns: colonnes, spacing: Grille.serre) {
            ForEach(Array(Monde.allCases.enumerated()), id: \.element) { rang, candidat in
                TuileMonde(monde: candidat, actif: candidat == monde) { bascule(candidat) }
                    .entreeEnScene(rang: rang)
            }
        }
        .padding(Grille.element)
        .background(Neutre.surface)
        .clipShape(.rect(cornerRadius: Rayon.feuille, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Rayon.feuille, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [Neutre.lumiereHaute, Neutre.lumiereBasse],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: Grille.trait
                )
        }
        .padding(.horizontal, Grille.serre)
        .padding(.top, Grille.serre)
        .scaleEffect(reduireMouvement || posee ? 1 : 0.96, anchor: .top)
        .onAppear {
            withAnimation(reduireMouvement ? Mouvement.fonduReduit : Mouvement.normal) { posee = true }
        }
    }
}

/// Une tuile : le glyphe dans un disque voilé de l'accent du monde, le nom, le
/// rôle. La tuile active est posée sur une surface haute.
private struct TuileMonde: View {
    let monde: Monde
    let actif: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Grille.serre) {
                Image(systemName: monde.symbole)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(TeinteEcho.accent(du: monde))
                    .frame(width: Grille.cible, height: Grille.cible)
                    .background(TeinteEcho.accent(du: monde).opacity(0.15), in: .circle)
                VStack(spacing: Grille.fin) {
                    Text(monde.titre)
                        .font(Voix.mention)
                        .foregroundStyle(Neutre.encre)
                    Text(monde.role)
                        .font(Voix.legende)
                        .foregroundStyle(Neutre.encreEteinte)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Grille.element)
            .background(actif ? Neutre.surfaceHaute : .clear,
                        in: .rect(cornerRadius: Rayon.carte, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(AppuiPupitre())
        .accessibilityLabel(monde.titre)
        .accessibilityAddTraits(actif ? .isSelected : [])
    }
}

/// L'appui du chrome : 0,97, comme partout.
private struct AppuiPupitre: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Mouvement.micro, value: configuration.isPressed)
    }
}
#endif
