// Le rendu formaté d'une note : markdown léger (gras/italique, liens
// `[txt](url)`) AVEC les retours à la ligne préservés, plus les URL nues rendues
// cliquables. Réutilisé par la carte d'inbox et l'aperçu.
//
// `☠` Tout est iOS-only : ni `AttributedString(markdown:options:)` ni
// `NSDataDetector` n'existent dans la Foundation de Linux. D'où le garde
// `#if canImport(SwiftUI)` — le module entier s'y réduit à vide sous `swift
// build`, et la vraie preuve est `xtool dev build`. Ce code n'est donc pas
// éprouvable dans `SailyNoyau` (Linux) : on n'y ajoute pas de test parallèle qui
// testerait un autre chemin que celui-ci.
#if canImport(SwiftUI)
import SwiftUI
import Foundation

/// Construit l'`AttributedString` d'une note. Pur (Foundation), sans état.
enum RenduNote {
    static func attribuee(_ texte: String) -> AttributedString {
        var attribuee = analyser(texte)
        autolier(&attribuee)
        return attribuee
    }

    /// `☠` `.inlineOnlyPreservingWhitespace` est le SEUL mode qui garde les
    /// retours à la ligne : le mode `.full` réduit les blancs et fond les lignes
    /// comme du HTML. On veut une note, pas un article.
    ///
    /// `☠` `returnPartiallyParsedIfPossible` + le repli garantissent qu'un
    /// markdown bancal (`[` orphelin, `*` non fermé) ne fait JAMAIS planter : on
    /// retombe sur le texte brut, retours compris.
    private static func analyser(_ texte: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        if let rendue = try? AttributedString(markdown: texte, options: options) {
            return rendue
        }
        return AttributedString(texte)
    }

    /// `☠` Le markdown n'autolie PAS une URL nue (`https://x` sans `[]()`). On la
    /// pose à la main via `NSDataDetector`, mais SANS écraser un lien markdown
    /// déjà présent — un `[texte](url)` garde sa cible.
    private static func autolier(_ attribuee: inout AttributedString) {
        let texte = String(attribuee.characters)
        guard !texte.isEmpty,
              let detecteur = try? NSDataDetector(
                  types: NSTextCheckingResult.CheckingType.link.rawValue
              )
        else { return }
        let etendue = NSRange(location: 0, length: (texte as NSString).length)
        detecteur.enumerateMatches(in: texte, range: etendue) { resultat, _, _ in
            appliquerLien(resultat, dans: &attribuee, texte: texte)
        }
    }

    private static func appliquerLien(
        _ resultat: NSTextCheckingResult?, dans attribuee: inout AttributedString, texte: String
    ) {
        guard let resultat, let url = resultat.url,
              let plage = Range(resultat.range, in: texte) else { return }
        let debut = texte.distance(from: texte.startIndex, to: plage.lowerBound)
        let fin = texte.distance(from: texte.startIndex, to: plage.upperBound)
        guard let borneDebut = attribuee.characters.index(
                  attribuee.startIndex, offsetBy: debut, limitedBy: attribuee.endIndex),
              let borneFin = attribuee.characters.index(
                  attribuee.startIndex, offsetBy: fin, limitedBy: attribuee.endIndex)
        else { return }
        let sousPlage = borneDebut..<borneFin
        if attribuee[sousPlage].link == nil { attribuee[sousPlage].link = url }
    }
}

/// La note rendue, prête à poser dans une carte ou un aperçu.
///
/// `☠` La couleur des liens vient du `.tint` (jeton `Teinte.accent`), jamais
/// d'une couleur nue posée sur les runs : c'est SwiftUI qui peint un `.link`
/// avec la teinte d'accent, et le corps de la note garde `Teinte.encre`.
struct NoteRendue: View {
    let texte: String
    /// Aperçu borné dans une liste ; `nil` en plein écran (édition, détail).
    var lignesMax: Int?

    var body: some View {
        Text(RenduNote.attribuee(texte))
            .corps()
            .foregroundStyle(Teinte.encre)
            .tint(Teinte.accent)
            .lineSpacing(Typo.interligneNote)
            .lineLimit(lignesMax)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
