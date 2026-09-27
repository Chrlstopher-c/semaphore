// Les pistes : ce que Tamis a repéré, trié par poids. En tête, l'analyse Vision
// qui nourrit trois d'entre elles — lancée à la main, parce qu'elle dure.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct PistesEcran: View {
    @Environment(Atelier.self) private var atelier

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Grille.section) {
                    Fronton("Pistes")
                    PanneauAnalyse()
                    liste
                }
                .padding(.horizontal, Grille.ecran)
                .padding(.vertical, Grille.groupe)
            }
            .background(Neutre.fond.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .destinationsTamis()
        }
    }

    private var releves: [Releve] { atelier.releves.sorted { $0.poids > $1.poids } }

    @ViewBuilder private var liste: some View {
        if releves.isEmpty {
            EtatCalme(symbole: "sparkle.magnifyingglass", titre: "Aucune piste pour l'instant",
                      detail: "Lance l'analyse : elle révèle les similaires, les ratées et les documents.")
        } else {
            VStack(alignment: .leading, spacing: Grille.element) {
                Text("Repéré").rubrique()
                ForEach(Array(releves.enumerated()), id: \.element.id) { rang, releve in
                    NavigationLink(value: destination(releve)) { RangeePiste(releve: releve) }
                        .buttonStyle(.appui)
                        .entreeEnScene(rang: rang)
                }
            }
        }
    }

    private func destination(_ releve: Releve) -> Destination {
        releve.piste.parGroupes
            ? .groupes(releve.piste)
            : .grille(titre: releve.piste.titre, ids: releve.proposes)
    }
}

private struct RangeePiste: View {
    let releve: Releve

    var body: some View {
        Panneau {
            HStack(alignment: .top, spacing: Grille.bloc) {
                Image(systemName: releve.piste.symbole)
                    .font(Voix.entete).foregroundStyle(Teinte.accent)
                    .frame(width: Grille.groupe)
                VStack(alignment: .leading, spacing: Grille.fin) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(releve.piste.titre).font(Voix.entete).foregroundStyle(Neutre.encre)
                        Spacer(minLength: Grille.serre)
                        Text(Octets.lisible(releve.poids)).font(Voix.mesure).foregroundStyle(Neutre.encre)
                    }
                    Text("\(releve.proposes.count.formatted()) proposés · \(releve.piste.explication)")
                        .font(Voix.note).foregroundStyle(Neutre.encreDouce)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}
#endif
