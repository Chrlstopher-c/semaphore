// La racine : la pile (liste Code → session) poussée vers la droite par le tiroir, et les feuilles globales.
// Étalon : le tiroir fait 313 pt, le contenu glisse d'autant et s'assombrit derrière lui.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

enum FeuilleRacine: String, Identifiable {
    case nouvelle, reglages, machines
    var id: String { rawValue }
}

struct RacineQuart: View {
    @Binding var pile: [String]
    @State private var tiroir = false
    @State private var glisse: CGFloat = 0
    @State private var feuille: FeuilleRacine?

    private let largeur: CGFloat = 313

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack(path: $pile) {
                ListeCodeEcran(nouvelleSession: { feuille = .nouvelle })
                    .navigationDestination(for: String.self) { SessionEcran(id: $0) }
            }
            .environment(\.ouvrirTiroir, { ouvrir(true) })
            .overlay { voile }
            .offset(x: decalage)
            .overlay(alignment: .leading) { bordGauche }
            Tiroir(choisir: choisir).frame(width: largeur).offset(x: decalage - largeur)
        }
        .background(Q.fondTiroir.ignoresSafeArea())
        .sheet(item: $feuille) { f in contenu(f) }
        .sensoryFeedback(.impact(weight: .light), trigger: tiroir)
    }

    private var decalage: CGFloat { min(max((tiroir ? largeur : 0) + glisse, 0), largeur) }

    /// Assombrit la pile quand le tiroir est ouvert ; un toucher ou un glissement le referme.
    private var voile: some View {
        Color.black.opacity(0.45 * decalage / largeur).ignoresSafeArea()
            .allowsHitTesting(tiroir)
            .onTapGesture { ouvrir(false) }
            .gesture(DragGesture().onChanged { glisse = min($0.translation.width, 0) }.onEnded(finGlisse))
    }

    /// À la racine seulement : glisser depuis le bord gauche ouvre le tiroir (ailleurs, ce geste est le retour).
    @ViewBuilder private var bordGauche: some View {
        if pile.isEmpty && !tiroir {
            Color.clear.frame(width: 20).contentShape(.rect)
                .gesture(DragGesture().onChanged { glisse = max($0.translation.width, 0) }.onEnded(finGlisse))
        }
    }

    private func finGlisse(_ g: DragGesture.Value) {
        let arrivee = g.predictedEndTranslation.width
        let cible = tiroir ? arrivee > -largeur / 3 : arrivee > largeur / 3
        withAnimation(.smooth(duration: 0.35)) { tiroir = cible; glisse = 0 }
    }

    private func ouvrir(_ etat: Bool) {
        withAnimation(.smooth(duration: 0.35)) { tiroir = etat; glisse = 0 }
    }

    private func choisir(_ choix: ChoixTiroir) {
        ouvrir(false)
        switch choix {
        case .code: pile = []
        case .session(let id): pile = [id]
        case .nouvelle: feuille = .nouvelle
        case .reglages: feuille = .reglages
        case .machines: feuille = .machines
        }
    }

    @ViewBuilder private func contenu(_ f: FeuilleRacine) -> some View {
        switch f {
        case .nouvelle: NouvelleSessionFeuille { id in pile = [id] }
        case .reglages: ReglagesFeuille()
        case .machines: AccesEcran().presentationBackground(Q.fondFil)
        }
    }
}
#endif
