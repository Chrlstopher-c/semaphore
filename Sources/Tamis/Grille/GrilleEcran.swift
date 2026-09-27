// Une sélection à revoir : ce qu'elle pèse, deux gestes de masse, la grille.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct GrilleEcran: View {
    @Environment(Atelier.self) private var atelier
    let titre: String
    let ids: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Grille.groupe) {
                entete.padding(.horizontal, Grille.ecran)
                if ids.isEmpty {
                    EtatCalme(symbole: "checkmark.circle", titre: "Rien ici", detail: "Cette sélection est vide.")
                } else {
                    GrilleVignettes(ids: ids)
                }
            }
            .padding(.vertical, Grille.groupe)
        }
        .pageTamis(titre)
    }

    private var entete: some View {
        let dedans = ids.filter { atelier.decisions.panier.contains($0) }
        let poids = ids.reduce(Int64(0)) { $0 + (atelier.index[$1]?.poids ?? 0) }
        return VStack(alignment: .leading, spacing: Grille.element) {
            Text("\(ids.count) éléments · \(Octets.lisible(poids))")
                .font(Voix.mention).foregroundStyle(Neutre.encreDouce)
                .contentTransition(.numericText())
            HStack(spacing: Grille.serre) {
                Button("Tout au panier") { atelier.mettreAuPanier(ids) }
                    .buttonStyle(.engage)
                    .disabled(dedans.count == ids.count)
                Button("Tout retirer") { atelier.oublier(dedans) }
                    .buttonStyle(.appui)
                    .font(Voix.entete)
                    .foregroundStyle(Neutre.encreDouce)
                    .frame(maxWidth: .infinity, minHeight: Grille.cible)
                    .background(Neutre.surface, in: .rect(cornerRadius: Rayon.controle, style: .continuous))
                    .disabled(dedans.isEmpty)
            }
            Text("Touche une photo pour l'ajouter ou la retirer. Appui long pour la voir en grand.")
                .font(Voix.note).foregroundStyle(Neutre.encreEteinte)
        }
    }
}
#endif
