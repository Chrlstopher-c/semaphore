// Rendu des tableaux markdown — le bloc qui justifie l'analyseur maison.
// `Grid` dimensionne les colonnes à leur contenu ; le défilement horizontal
// absorbe un tableau plus large que l'écran plutôt que de le tasser illisible.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

extension RenduMarkdown {

    func vueTableau(_ table: TableauMarkdown) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: Trame.bloc, verticalSpacing: Trame.serre) {
                GridRow {
                    ForEach(Array(table.entete.enumerated()), id: \.offset) { indice, contenu in
                        cellule(contenu, alignement: table.alignement(indice), entete: true)
                    }
                }
                FiletFin().gridCellColumns(table.colonnes)
                ForEach(Array(table.lignes.enumerated()), id: \.offset) { _, ligne in
                    GridRow {
                        ForEach(Array(ligne.enumerated()), id: \.offset) { indice, contenu in
                            cellule(contenu, alignement: table.alignement(indice), entete: false)
                        }
                    }
                }
            }
            .padding(Trame.element)
        }
        .background(
            Teinte.fondCreux,
            in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                .strokeBorder(Teinte.filet, lineWidth: Trame.trait)
        )
    }

    /// L'alignement déclaré est respecté : un tableau de mesures aligné à
    /// droite se lit d'un coup d'œil, et c'est la forme des rendus de leads.
    private func cellule(
        _ contenu: [FragmentTexte],
        alignement: AlignementColonne,
        entete: Bool
    ) -> some View {
        Group {
            if entete {
                texteFragments(contenu).note().bold().foregroundStyle(Teinte.encre)
            } else {
                texteFragments(contenu).note().foregroundStyle(Teinte.encreDouce)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignementSwiftUI(alignement))
    }

    private func alignementSwiftUI(_ alignement: AlignementColonne) -> Alignment {
        switch alignement {
        case .gauche: return .leading
        case .centre: return .center
        case .droite: return .trailing
        }
    }
}
#endif
