import Foundation

/// Le texte d'une dictée en cours, indépendamment de tout micro.
///
/// Speech clôt une phrase à chaque silence et repart de zéro au résultat
/// suivant : c'est ce qui fait disparaître tout ce qui précède la pause si on
/// se contente d'afficher la dernière transcription. Une phrase close devient
/// donc ici un segment acquis, et seule la phrase en cours est réécrite.
///
/// `base` est ce que Chris avait déjà tapé quand il a pris le micro : la dictée
/// s'ajoute à son brouillon, elle ne le remplace jamais.
public struct AssemblageDictee: Equatable, Sendable {
    public private(set) var base: String
    /// Phrases closes par Speech. Elles ne bougent plus.
    public private(set) var segments: [String] = []
    /// Phrase en cours, réécrite à chaque mot reconnu.
    public private(set) var segment = ""

    public init(base: String = "") {
        self.base = base
    }

    /// Le texte tel qu'il doit s'afficher dans le champ, à l'instant présent.
    public var texte: String {
        let dicte = (segments + [Self.rogner(segment)])
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !dicte.isEmpty else { return base }
        guard !base.isEmpty else { return dicte }
        return base + Self.jointure(apres: base) + dicte
    }

    /// Rien n'a encore été reconnu : le bouton d'envoi doit rester froid.
    public var vide: Bool {
        segments.isEmpty && Self.rogner(segment).isEmpty
    }

    public mutating func poser(_ transcription: String) {
        segment = transcription
    }

    /// Speech a clos la phrase : elle passe dans l'acquis. Ce n'est pas la fin
    /// de la dictée — seul Chris l'arrête.
    public mutating func consolider() {
        let close = Self.rogner(segment)
        if !close.isEmpty { segments.append(close) }
        segment = ""
    }

    /// Le champ a été édité au clavier pendant la dictée : la nouvelle base est
    /// ce que Chris voit, et l'acquis repart de là. Sans ça, le premier mot
    /// reconnu ensuite écraserait sa correction.
    public mutating func reprendreSur(_ texte: String) {
        base = texte
        segments = []
        segment = ""
    }

    /// Un espace ne s'ajoute qu'entre deux mots, jamais après un saut de ligne
    /// ou un espace déjà là.
    private static func jointure(apres base: String) -> String {
        guard let dernier = base.last else { return "" }
        return dernier.isWhitespace || dernier.isNewline ? "" : " "
    }

    private static func rogner(_ texte: String) -> String {
        texte.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
