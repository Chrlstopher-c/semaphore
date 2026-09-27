// Une piste revue groupe par groupe : l'élue encadrée de citron, les autres
// proposées au panier. Toucher une vignette la bascule ; « Appliquer » fait tout
// d'un coup ce que Tamis propose.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct GroupesEcran: View {
    @Environment(Atelier.self) private var atelier
    let piste: Piste

    private var releve: Releve? { atelier.releves.first { $0.piste == piste } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Grille.groupe) {
                entete.padding(.horizontal, Grille.ecran)
                ForEach(releve?.groupes ?? [], id: \.self) { groupe in
                    RangeeGroupe(ids: groupe)
                }
            }
            .padding(.vertical, Grille.groupe)
        }
        .pageTamis(piste.titre)
    }

    private var entete: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            Text(piste.explication).font(Voix.note).foregroundStyle(Neutre.encreDouce)
            if let releve {
                Button("Garder les élues, \(releve.proposes.count.formatted()) au panier") {
                    atelier.mettreAuPanier(releve.proposes)
                }
                .buttonStyle(.engage)
                .disabled(releve.proposes.allSatisfy { atelier.decisions.panier.contains($0) })
            } else {
                EtatCalme(symbole: "checkmark.circle", titre: "Plus rien ici", detail: "Cette piste est épuisée.")
            }
        }
    }
}

/// Un groupe, en rangée défilante.
private struct RangeeGroupe: View {
    @Environment(Atelier.self) private var atelier
    let ids: [String]

    private var elue: String? {
        Election.meilleur(ids, cliches: atelier.index, qualites: atelier.carnet.qualites,
                          gardes: atelier.decisions.gardes)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Trame.jointure) {
                ForEach(ids, id: \.self) { id in
                    if let cliche = atelier.index[id] { vignette(cliche) }
                }
            }
            .padding(.horizontal, Grille.ecran)
        }
    }

    private func vignette(_ cliche: Cliche) -> some View {
        let estElue = cliche.id == elue
        return Button { atelier.basculerPanier(cliche.id) } label: {
            CaseCliche(cliche: cliche, auPanier: atelier.decisions.panier.contains(cliche.id),
                       garde: atelier.decisions.gardes.contains(cliche.id))
                .frame(width: Trame.vignetteGroupe, height: Trame.vignetteGroupe)
                .overlay {
                    if estElue {
                        Rectangle().strokeBorder(Teinte.accent, lineWidth: Trame.traitElue)
                    }
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Garder", systemImage: "heart") { atelier.garder([cliche.id]) }
        } preview: {
            Apercu(cliche: cliche)
        }
    }
}
#endif
