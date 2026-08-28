// Rendu des listes markdown : puce ou numéro, imbrication à plat via
// `EntreeListe.niveau`, case à cocher pour une liste de tâches.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

extension RenduMarkdown {

    func vueListe(_ entrees: [EntreeListe]) -> some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            ForEach(Array(entrees.enumerated()), id: \.offset) { _, entree in
                vueEntree(entree)
            }
        }
    }

    private func vueEntree(_ entree: EntreeListe) -> some View {
        HStack(alignment: .top, spacing: Trame.serre) {
            marqueur(entree)
            texteFragments(entree.contenu)
                .phrase()
                .foregroundStyle(Teinte.encre)
                .strikethrough(entree.cochee == true)
                .opacity(entree.cochee == true ? 0.55 : 1)
        }
        .padding(.leading, CGFloat(entree.niveau) * 16)
    }

    @ViewBuilder
    private func marqueur(_ entree: EntreeListe) -> some View {
        if let cochee = entree.cochee {
            Image(systemName: cochee ? "checkmark.square.fill" : "square")
                .font(.system(size: 12))
                .foregroundStyle(cochee ? Teinte.sain : Teinte.encreTernie)
                .frame(width: 16, alignment: .center)
                .padding(.top, 2)
        } else {
            Text(entree.puce)
                .donneePetite()
                .foregroundStyle(Teinte.accent.opacity(0.8))
                .frame(minWidth: 16, alignment: .trailing)
                .padding(.top, 1)
        }
    }
}
#endif
