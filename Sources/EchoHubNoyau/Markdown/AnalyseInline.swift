import Foundation

/// L'analyse du niveau inline : code, gras, emphase, liens.
///
/// Un motif unique parcouru UNE seule fois, plutôt qu'une succession de
/// remplacements : le texte hors motif reste du texte brut, ce qui garantit
/// qu'aucun caractère reçu n'est perdu — la concaténation des segments redonne
/// exactement la source. Porté de `frontend/src/chat/markdown/inline.ts`.
public enum AnalyseInline {
    /// `☠` `_souligné_` n'est volontairement PAS reconnu : il découperait
    /// `nom_de_variable` en emphase au milieu d'un identifiant, cas bien plus
    /// fréquent dans une réponse technique que l'italique.
    private static let motif = try? NSRegularExpression(
        pattern: "`([^`]+)`|\\*\\*([^*]+)\\*\\*|\\*([^*\\n]+)\\*|\\[([^\\]]+)\\]\\(([^)\\s]+)\\)"
    )

    /// Découpe une ligne en segments typés. Un marqueur ouvert mais pas encore
    /// refermé (`**gras` en cours de streaming) ne correspond à aucun motif : il
    /// ressort en TEXTE, il ne disparaît pas.
    public static func analyser(_ source: String) -> [SegmentInline] {
        guard let motif, !source.isEmpty else {
            return source.isEmpty ? [] : [.texte(source)]
        }
        let entier = NSRange(source.startIndex..., in: source)
        var segments: [SegmentInline] = []
        var curseur = source.startIndex
        for trouve in motif.matches(in: source, range: entier) {
            guard let plage = Range(trouve.range, in: source) else { continue }
            if plage.lowerBound > curseur {
                segments.append(.texte(String(source[curseur..<plage.lowerBound])))
            }
            segments.append(segment(trouve, dans: source))
            curseur = plage.upperBound
        }
        if curseur < source.endIndex { segments.append(.texte(String(source[curseur...]))) }
        return segments
    }

    private static func segment(_ trouve: NSTextCheckingResult, dans source: String) -> SegmentInline {
        if let code = capture(trouve, 1, source) { return .code(code) }
        if let fort = capture(trouve, 2, source) { return .fort(fort) }
        if let emphase = capture(trouve, 3, source) { return .emphase(emphase) }
        return .lien(
            texte: capture(trouve, 4, source) ?? "", cible: capture(trouve, 5, source) ?? ""
        )
    }

    /// Un groupe non apparié vaut `NSNotFound` : le ramener à `nil` plutôt que
    /// de le laisser produire une plage aberrante.
    private static func capture(
        _ trouve: NSTextCheckingResult, _ rang: Int, _ source: String
    ) -> String? {
        guard rang < trouve.numberOfRanges,
              let plage = Range(trouve.range(at: rang), in: source) else { return nil }
        return String(source[plage])
    }
}
