// Le panier : ce qui va partir, ce que ça libère, et le seul geste destructif du
// monde. La note sous le bouton n'est pas décorative — sans elle, Chris
// s'étonnerait qu'iCloud ne bouge pas.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct PanierEcran: View {
    @Environment(Atelier.self) private var atelier
    @State private var enCours = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Grille.groupe) {
                    entete.padding(.horizontal, Grille.ecran)
                    if atelier.decisions.panier.isEmpty {
                        EtatCalme(symbole: "trash", titre: "Panier vide",
                                  detail: "Glisse à gauche dans Tri, ou suis une piste.")
                    } else {
                        GrilleVignettes(ids: atelier.panier.map(\.id))
                    }
                }
                .padding(.vertical, Grille.groupe)
            }
            .background(Neutre.fond.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(Toucher.reussite, trigger: atelier.bilan) { _, b in b?.echec == nil && b != nil }
        }
    }

    private var entete: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            Fronton("Panier")
            Text(Octets.lisible(atelier.poidsPanier))
                .font(Voix.poidsHeros).foregroundStyle(Teinte.depart)
                .contentTransition(.numericText())
                .animation(Mouvement.normal, value: atelier.poidsPanier)
            Text("\(atelier.decisions.panier.count.formatted()) éléments à supprimer · touche pour retirer")
                .font(Voix.mention).foregroundStyle(Neutre.encreDouce)
            if let bilan = atelier.bilan { bandeau(bilan).transition(.item) }
            Button(action: vider) {
                Label(enCours ? "Suppression…" : "Supprimer", systemImage: "trash")
            }
            .buttonStyle(.depart)
            .disabled(atelier.decisions.panier.isEmpty || enCours)
            Text("Photos demandera confirmation. Les éléments passent 30 jours dans « Supprimés récemment » "
                 + "avant de quitter iCloud : vide cet album dans Photos pour libérer l'espace tout de suite.")
                .font(Voix.note).foregroundStyle(Neutre.encreEteinte)
        }
        .animation(Mouvement.normal, value: atelier.bilan)
    }

    private func bandeau(_ bilan: Bilan) -> Bandeau {
        if let echec = bilan.echec {
            return Bandeau("Suppression impossible", remede: echec, ton: .alerte)
        }
        return Bandeau("\(bilan.nombre.formatted()) éléments supprimés · \(Octets.lisible(bilan.poids))",
                       remede: "Ils sont dans « Supprimés récemment ».", ton: .ok)
    }

    private func vider() {
        enCours = true
        Task {
            await atelier.viderPanier()
            enCours = false
        }
    }
}
#endif
