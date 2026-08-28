// Ce qui est COUPÉ se voit, sans ouvrir la feuille.
//
// `☠` Le réglage des outils existait déjà — catalogue, bascule par outil, coût
// en tokens — mais il vivait derrière un menu `…` de la barre de navigation, et
// Chris ne l'a pas trouvé en se servant de l'app. Un réglage qu'on ne trouve
// pas n'existe pas.
//
// `☠` Le rappel ne s'affiche QUE si quelque chose est coupé. C'est ce qui
// permet de tenir la charte : dans le régime nominal — tous les outils actifs —
// le fil reste nu, et rien de la machine n'y entre. Quand Chris a restreint,
// l'état devient une information qu'il a lui-même provoquée, et la ligne est
// aussi le chemin du retour.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct RappelOutils: View {
    let selection: SelectionOutils
    let total: Int?
    let ouvrir: () -> Void

    var body: some View {
        if selection.restreinte {
            Button(action: ouvrir) { contenu }
                .buttonStyle(.appui)
                .transition(.scene)
        }
    }

    private var contenu: some View {
        HStack(spacing: Trame.serre) {
            Image(systemName: aucun ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver")
                .imageScale(.small)
                .foregroundStyle(ton.couleur)
            Text("Outils : \(selection.resume(surTotal: total).lowercased())")
                .legende()
                .foregroundStyle(Teinte.encreDouce)
            Spacer(minLength: 0)
            Text("Changer").legende().foregroundStyle(Teinte.accent)
        }
        .padding(.horizontal, Trame.ecran)
        .padding(.vertical, Trame.serre)
        .contentShape(.rect)
    }

    /// Aucun outil est le seul cas qui mérite un ton : c'est celui où le modèle
    /// ne peut ni chercher ni lire, et où une réponse qui l'aurait exigé
    /// paraîtra simplement fausse.
    private var aucun: Bool { selection.outilsActifs?.isEmpty == true }

    private var ton: Ton { aucun ? .alerte : .neutre }
}
#endif
