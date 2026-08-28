// Le rendu markdown de Vigie, étage VUES. `AnalyseurMarkdown` (VigieNoyau,
// pur) fait le travail difficile ; ce fichier pose un `View` sur chaque
// `BlocMarkdown`. Titres, paragraphes, citations et filets ici — listes,
// tableaux et code dans leurs propres fichiers.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Rend une source markdown complète — le composant qui manque à
/// `AttributedString(markdown:)` : titres, listes, tableaux, blocs de code.
public struct RenduMarkdown: View {
    private let blocs: [BlocRange]

    public init(_ source: String) {
        blocs = AnalyseurMarkdown.blocs(source)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            ForEach(blocs) { entree in
                vue(pour: entree.bloc)
            }
        }
    }

    @ViewBuilder
    private func vue(pour bloc: BlocMarkdown) -> some View {
        switch bloc {
        case .titre(let niveau, let contenu):
            vueTitre(niveau: niveau, contenu: contenu)
        case .paragraphe(let contenu):
            texteFragments(contenu)
                .phrase()
                .foregroundStyle(Teinte.encre)
                .lineSpacing(2.5)
                .textSelection(.enabled)
        case .liste(let entrees):
            vueListe(entrees)
        case .code(let langage, let texte, let ouvert):
            vueCode(langage: langage, texte: texte, ouvert: ouvert)
        case .tableau(let table):
            vueTableau(table)
        case .citation(let contenu):
            vueCitation(contenu)
        case .filet:
            FiletFin().padding(.vertical, Trame.fin)
        }
    }

    /// Les titres d'un rendu de lead prennent la voix serif des titres de la
    /// charte : c'est un DOCUMENT qu'on lit, pas un message.
    @ViewBuilder
    private func vueTitre(niveau: Int, contenu: [FragmentTexte]) -> some View {
        let texte = texteFragments(contenu).foregroundStyle(Teinte.encre)
        switch niveau {
        case 1: texte.font(.system(size: 21, weight: .semibold, design: .serif))
        case 2: texte.font(.system(size: 18, weight: .semibold, design: .serif))
        default: texte.phraseForte()
        }
    }

    private func vueCitation(_ contenu: [FragmentTexte]) -> some View {
        HStack(alignment: .top, spacing: Trame.serre) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Teinte.accent.opacity(0.5))
                .frame(width: 3)
            texteFragments(contenu)
                .note()
                .italic()
                .foregroundStyle(Teinte.encreDouce)
        }
    }
}
#endif
