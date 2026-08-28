// Rendu des blocs de code : l'îlot le plus sombre de la page, mono, défilement
// horizontal — un code replié à la largeur devient illisible avant d'être court.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

extension RenduMarkdown {

    func vueCode(langage: String?, texte: String, ouvert: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if langage != nil || ouvert {
                enTeteCode(langage: langage, ouvert: ouvert)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(texte)
                    .texteTerminal()
                    .foregroundStyle(Teinte.terminalTexte)
                    .textSelection(.enabled)
                    .padding(Trame.element)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Teinte.terminalFond,
            in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                .strokeBorder(Teinte.filet, lineWidth: Trame.trait)
        )
    }

    private func enTeteCode(langage: String?, ouvert: Bool) -> some View {
        HStack(spacing: Trame.serre) {
            if let langage {
                Text(langage)
                    .donneeMinuscule()
                    .foregroundStyle(Teinte.encreTernie)
            }
            Spacer(minLength: 0)
            // `ouvert` = la clôture n'est pas arrivée : le régime NORMAL
            // pendant que l'orchestrateur écrit, pas une erreur de syntaxe.
            if ouvert { SouffleActivite() }
        }
        .padding(.horizontal, Trame.element)
        .padding(.top, Trame.serre)
    }
}
#endif
