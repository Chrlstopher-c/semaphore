// Le tri rapide : une photo à la fois, glisser à gauche pour le panier, à droite
// pour la garder. Le geste le plus rapide qui soit pour trier des milliers
// d'images — et le seul écran du monde où l'on va vite.
//
// `☠` Rien n'est supprimé ici : la gauche remplit le panier, qu'on vide ensuite
// en une fois. Une erreur se rattrape par « Annuler » jusqu'au dernier geste.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct TriEcran: View {
    @Environment(Atelier.self) var atelier
    @Environment(\.accessibilityReduceMotion) var reduire
    @State private var source: SourceTri = .anciennes
    @State var file: [String] = []
    @State var historique: [String] = []
    @State var glisse: CGFloat = 0
    @State var jete: Int64 = 0
    /// Vrai pendant l'envol d'une carte : un second geste attend qu'elle soit partie.
    @State var enVol = false

    var courant: Cliche? { file.first.flatMap { atelier.index[$0] } }

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.groupe) {
            entete
            pile.frame(maxHeight: .infinity)
            commandes
        }
        .padding(.horizontal, Grille.ecran)
        .padding(.vertical, Grille.groupe)
        .background(Neutre.fond.ignoresSafeArea())
        .onAppear(perform: remplir)
        .onChange(of: source) { _, _ in remplir() }
        .onChange(of: atelier.cliches.count) { _, _ in remplir() }
        .sensoryFeedback(Toucher.selection, trigger: source)
    }

    private func remplir() {
        let decides = atelier.decisions.panier.union(atelier.decisions.gardes)
        file = source.file(atelier.cliches, decides: decides)
    }

    private var entete: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            HStack(alignment: .firstTextBaseline) {
                Fronton("Tri")
                Spacer(minLength: 0)
                Text("\(file.count.formatted()) à trier").font(Voix.mesure).foregroundStyle(Neutre.encreEteinte)
            }
            Picker("Source", selection: $source) {
                ForEach(SourceTri.allCases, id: \.self) { Text($0.libelle).tag($0) }
            }
            .pickerStyle(.segmented)
            if jete > 0 {
                Text("Cette séance : \(Octets.lisible(jete)) au panier")
                    .font(Voix.mention).foregroundStyle(Teinte.depart)
                    .contentTransition(.numericText())
            }
        }
    }

    @ViewBuilder private var pile: some View {
        if let courant {
            ZStack {
                if file.count > 1, let suivant = atelier.index[file[1]] {
                    CarteTri(cliche: suivant, glisse: 0).scaleEffect(0.95).opacity(0.5)
                }
                CarteTri(cliche: courant, glisse: glisse)
                    .id(courant.id)
                    .offset(x: glisse)
                    .rotationEffect(.degrees(Double(glisse) / 25))
                    .gesture(glisser)
                    .transition(.opacity)
            }
        } else {
            EtatCalme(symbole: "checkmark.seal", titre: "Tout est trié ici",
                      detail: "Change de source, ou va voir les pistes.")
                .frame(maxHeight: .infinity)
        }
    }

    private var glisser: some Gesture {
        DragGesture()
            .onChanged { glisse = $0.translation.width }
            .onEnded { fin in
                let x = fin.predictedEndTranslation.width
                if x < -Trame.seuilGlisse { juger(auPanier: true) } else if x > Trame.seuilGlisse {
                    juger(auPanier: false)
                } else {
                    withAnimation(Mouvement.normal) { glisse = 0 }
                }
            }
    }
}
#endif
