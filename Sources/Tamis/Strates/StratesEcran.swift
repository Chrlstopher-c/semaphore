// L'écran d'accueil de Tamis : le poids de la photothèque, puis ses couches
// année par année. Il répond à la question qui fait ouvrir l'app — où est le
// poids ? — et mène aux deux gestes pour le faire baisser.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct StratesEcran: View {
    @Environment(Atelier.self) private var atelier
    @State private var ouverte: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Grille.section) {
                    Heros()
                    NavigationLink(value: Destination.plage) {
                        Label("Tamiser une période", systemImage: "calendar")
                    }
                    .buttonStyle(.engage)
                    strates
                }
                .padding(.horizontal, Grille.ecran)
                .padding(.vertical, Grille.groupe)
            }
            .background(Neutre.fond.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .destinationsTamis()
        }
    }

    private var strates: some View {
        let plusLourde = atelier.strates.map(\.annee.poids).max() ?? 1
        return VStack(alignment: .leading, spacing: Grille.element) {
            Text("Strates").rubrique()
            ForEach(Array(atelier.strates.enumerated()), id: \.element.id) { rang, strate in
                StrateBloc(strate: strate, reference: plusLourde, ouverte: $ouverte)
                    .entreeEnScene(rang: rang)
            }
        }
        .sensoryFeedback(Toucher.selection, trigger: ouverte)
    }
}

/// Le poids total, et ce que le panier en retirera.
private struct Heros: View {
    @Environment(Atelier.self) private var atelier

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.fin) {
            HStack(alignment: .firstTextBaseline) {
                Fronton("Tamis")
                Spacer(minLength: 0)
                if atelier.accesLimite { Sceau("Accès limité", symbole: "lock", ton: .alerte) }
            }
            Text(Octets.lisible(atelier.poidsTotal))
                .font(Voix.poidsHeros)
                .foregroundStyle(Neutre.encre)
                .contentTransition(.numericText())
                .animation(Mouvement.normal, value: atelier.poidsTotal)
                .padding(.top, Grille.element)
            Text(detail).font(Voix.mention).foregroundStyle(Neutre.encreDouce)
            if atelier.poidsPanier > 0 {
                Text("− \(Octets.lisible(atelier.poidsPanier)) au panier")
                    .font(Voix.mention).foregroundStyle(Teinte.depart)
                    .transition(.item)
            }
        }
        .animation(Mouvement.normal, value: atelier.poidsPanier > 0)
    }

    private var detail: String {
        let nombre = atelier.cliches.count.formatted()
        guard atelier.aPeser > 0 else { return "\(nombre) photos et vidéos" }
        return "\(nombre) éléments · pesée en cours, \(atelier.aPeser.formatted()) restants"
    }
}
#endif
