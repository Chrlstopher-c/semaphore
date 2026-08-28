// Le rendu d'un tableau markdown sur 375 pt.
//
// Structure reprise de `Vigie/Charte/Markdown/RenduMarkdownTableau.swift` — même
// chaîne, mêmes noms de jetons, et une forme déjà éprouvée : `Grid` dimensionne
// les colonnes à leur contenu, un filet UNIQUE sépare l'en-tête du corps, et le
// défilement horizontal absorbe ce qui dépasse. Copié, pas référencé : aucune
// dépendance entre les deux dépôts.
//
// `☠` C'est le TABLEAU qui défile, jamais la page. Sans défilement propre, une
// grille de quatre colonnes est soit repliée au milieu d'un mot, soit coupée
// net ; et une page qui part de travers emporte tout le fil avec elle.
//
// `☠` Un seul filet, sous l'en-tête. La charte impose l'ordre : on sépare
// d'abord par l'espacement, ensuite par un changement de surface, en dernier
// recours par une bordure. Une bordure sous chaque rangée serait le dernier
// recours appliqué en premier.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct RenduTableau: View {
    let tableau: TableauMarkdown

    /// Une colonne qui prendrait toute la largeur repousse les suivantes hors
    /// de portée du pouce. Hors grille `Trame` : c'est une largeur de texte,
    /// pas une mise en page.
    private let largeurMax: CGFloat = 200

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(
                alignment: .topLeading,
                horizontalSpacing: Trame.bloc, verticalSpacing: Trame.serre
            ) {
                entete
                Rectangle().fill(Teinte.trait).frame(height: Trame.trait)
                    .gridCellColumns(max(tableau.colonnes, 1))
                corps
            }
            .padding(Trame.element)
        }
        .background(
            Teinte.fond, in: RoundedRectangle(cornerRadius: Galbe.controle, style: .continuous)
        )
        .lisere(Galbe.controle)
    }

    private var entete: some View {
        GridRow {
            ForEach(Array(tableau.entetes.enumerated()), id: \.offset) { colonne, contenu in
                cellule(contenu, colonne: colonne, entete: true)
            }
        }
    }

    private var corps: some View {
        ForEach(Array(tableau.lignes.enumerated()), id: \.offset) { _, ligne in
            GridRow {
                ForEach(Array(ligne.enumerated()), id: \.offset) { colonne, contenu in
                    cellule(contenu, colonne: colonne, entete: false)
                }
            }
        }
    }

    /// `☠` Les cellules descendent en `mention` (15) et n'y remontent jamais.
    /// Une grille en corps 17 ne tient sur aucune largeur utile — et le plafond
    /// de la charte tient quand même : rien ne monte AU-DESSUS de ce que le
    /// modèle répond, une descente est toujours permise.
    private func cellule(
        _ segments: [SegmentInline], colonne: Int, entete: Bool
    ) -> some View {
        Text(assemblee(segments))
            .font(entete ? Typo.mention.weight(.semibold) : Typo.mention)
            .foregroundStyle(Teinte.encre)
            .multilineTextAlignment(textuelle(colonne))
            .frame(maxWidth: largeurMax, alignment: cadrage(colonne))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// `☠` La composition ne FIXE aucune police, contrairement à
    /// `RenduMarkdown.compose` qui pose `Typo.entete` sur un gras et
    /// `Typo.corps` sur une emphase. Dans un paragraphe c'est juste ; dans une
    /// cellule à 15 pt, un mot en gras sauterait à 17 et casserait la rangée.
    /// L'intention de présentation laisse le fragment HÉRITER de la police du
    /// conteneur — la solution retenue dans Vigie pour la même raison.
    private func assemblee(_ segments: [SegmentInline]) -> AttributedString {
        segments.reduce(into: AttributedString()) { total, segment in
            total.append(Self.attribue(segment))
        }
    }

    static func attribue(_ segment: SegmentInline) -> AttributedString {
        var morceau = AttributedString(segment.brut)
        switch segment {
        case .texte:
            break
        case .fort:
            morceau.inlinePresentationIntent = .stronglyEmphasized
        case .emphase:
            morceau.inlinePresentationIntent = .emphasized
        case .code:
            morceau.inlinePresentationIntent = .code
        case .lien(_, let cible):
            morceau.foregroundColor = Teinte.accent
            morceau.underlineStyle = .single
            if let url = URL(string: cible) { morceau.link = url }
        }
        return morceau
    }

    /// Une colonne sans délimiteur lu est cadrée à gauche : c'est ce que dit un
    /// `---` nu, pas un défaut choisi ici.
    private func alignement(_ colonne: Int) -> Alignement {
        tableau.alignements.indices.contains(colonne) ? tableau.alignements[colonne] : .gauche
    }

    private func textuelle(_ colonne: Int) -> TextAlignment {
        switch alignement(colonne) {
        case .gauche: return .leading
        case .centre: return .center
        case .droite: return .trailing
        }
    }

    private func cadrage(_ colonne: Int) -> Alignment {
        switch alignement(colonne) {
        case .gauche: return .leading
        case .centre: return .center
        case .droite: return .trailing
        }
    }
}
#endif
