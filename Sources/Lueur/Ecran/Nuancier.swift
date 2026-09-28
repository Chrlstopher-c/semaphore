// Les couleurs prêtes : douze préréglages, puis les favoris (menu contextuel pour retirer).
#if canImport(SwiftUI) && canImport(UIKit)
import LueurNoyau
import SwiftUI
import Systeme

struct Nuancier: View {
    @Environment(Lampe.self) private var lampe

    private static let prereglages = ["#ffffff", "#ffb46b", "#ff0000", "#ff6a00", "#ffd000", "#00ff40",
                                      "#00e5ff", "#0040ff", "#8000ff", "#ff00ff", "#ff2d6f", "#ff8fa8"]
        .compactMap(Nuance.init(hexa:))
    private let colonnes = Array(repeating: GridItem(.flexible(), spacing: Grille.serre), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            HStack {
                Text("Couleurs").rubrique()
                Spacer()
                if let couleur = lampe.couleur {
                    Button("Garder", systemImage: "star") { lampe.envoyer(.ajouterFavori(couleur.hexa)) }
                        .font(Voix.mention)
                        .frame(minHeight: Grille.cible)
                }
            }
            grille(Self.prereglages, retirable: false)
            if !favoris.isEmpty {
                Text("Favoris").rubrique()
                grille(favoris, retirable: true)
            }
        }
        .sensoryFeedback(Toucher.selection, trigger: lampe.etat?.couleur)
    }

    private var favoris: [Nuance] { (lampe.etat?.favoris ?? []).compactMap(Nuance.init(hexa:)) }

    private func grille(_ nuances: [Nuance], retirable: Bool) -> some View {
        LazyVGrid(columns: colonnes, spacing: Grille.serre) {
            ForEach(nuances, id: \.self) { nuance in
                pastille(nuance)
                    .contextMenu {
                        if retirable {
                            Button("Retirer des favoris", systemImage: "star.slash", role: .destructive) {
                                lampe.envoyer(.retirerFavori(nuance.hexa))
                            }
                        }
                    }
            }
        }
    }

    private func pastille(_ nuance: Nuance) -> some View {
        let active = lampe.etat?.effet == nil && lampe.couleur == nuance
        return Button {
            lampe.envoyer(.couleur(nuance))
        } label: {
            Circle()
                .fill(Color(nuance: nuance))
                .overlay(Circle().strokeBorder(active ? Neutre.encre : Neutre.trait, lineWidth: active ? 2 : 1))
                .frame(width: Trame.pastille, height: Trame.pastille)
                .contentShape(Circle())
        }
        .buttonStyle(Presse())
        .accessibilityLabel(nuance.hexa)
    }
}
#endif
