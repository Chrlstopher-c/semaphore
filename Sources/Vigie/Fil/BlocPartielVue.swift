// Le bloc en cours de frappe — la seule raison d'être de la cadence 400 ms.
// Re-analysé en markdown à chaque sondage : `AnalyseurMarkdown` est pur et
// rapide, et un bloc encore ouvert (code non refermé) n'est pas une erreur.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct BlocPartielVue: View {
    let partiel: PartielApi

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            contenu
            SouffleActivite(teinte: Teinte.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id("partiel-en-cours")
    }

    @ViewBuilder private var contenu: some View {
        switch partiel.type {
        case .reflexion:
            VStack(alignment: .leading, spacing: Trame.fin) {
                HStack(spacing: Trame.fin + 1) {
                    Image(systemName: "brain").font(.system(size: 10))
                    Text("Raisonnement").mention()
                }
                .foregroundStyle(Teinte.encreTernie)
                Text(partiel.contenu)
                    .note()
                    .italic()
                    .foregroundStyle(Teinte.encreDouce)
            }
        default:
            RenduMarkdown(partiel.contenu)
        }
    }
}
#endif
