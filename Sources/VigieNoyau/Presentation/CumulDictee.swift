import Foundation

// Responsabilité : le texte d'une dictée en cours. Base = champ au démarrage (ou après une retouche à la main) ;
// segments finalisés cumulés ; seul le segment en cours (partiel) est remplacé. `SFSpeechRecognizer` repart sur un
// nouveau segment après un silence, parfois SANS résultat final : un partiel qui ne prolonge pas le précédent fige
// celui-ci au lieu de l'effacer (défaut constaté : la première phrase disparaissait à chaque pause). Pur.

public struct CumulDictee: Sendable, Equatable {
    public private(set) var base: String
    public private(set) var finalises = ""
    public private(set) var partiel = ""

    public init(base: String) { self.base = base }

    /// Le texte à montrer dans le champ.
    public var texte: String { Self.joindre(Self.joindre(base, finalises), partiel) }
    /// Tout sauf le segment en cours (affiché plein, le partiel l'est en estompé).
    public var acquis: String { Self.joindre(base, finalises) }

    /// Un résultat de la tâche de reconnaissance. Final : le segment rejoint les finalisés, un nouveau commence.
    public mutating func resultat(_ texte: String, fin: Bool) {
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.repart(propre, apres: partiel) { figer() }
        if fin {
            finalises = Self.joindre(finalises, propre)
            partiel = ""
        } else {
            partiel = propre
        }
    }

    /// La tâche de reconnaissance redémarre (silence, limite d'une minute, erreur) : le partiel est gardé.
    public mutating func figer() {
        finalises = Self.joindre(finalises, partiel)
        partiel = ""
    }

    /// Le champ a été retouché à la main pendant la dictée : ce qu'il contient devient la base, rien n'est réécrit.
    public mutating func champModifie(_ champ: String) {
        base = champ
        finalises = ""
        partiel = ""
    }

    /// Le nouveau partiel ne prolonge pas l'ancien : la reconnaissance a commencé un autre segment.
    static func repart(_ nouveau: String, apres ancien: String) -> Bool {
        guard !ancien.isEmpty, !nouveau.isEmpty else { return false }
        if premierMot(nouveau) != premierMot(ancien) { return true }
        return nouveau.count * 2 < ancien.count
    }

    static func premierMot(_ texte: String) -> String {
        let mot = texte.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        return mot.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }

    /// Accole `suite` à `avant` avec une espace si besoin ; pas d'espace avant une ponctuation fermante.
    public static func joindre(_ avant: String, _ suite: String) -> String {
        let segment = suite.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !segment.isEmpty else { return avant }
        guard let dernier = avant.last, !dernier.isWhitespace else { return avant + segment }
        if let premier = segment.first, ",.;:!?)…".contains(premier) { return avant + segment }
        return avant + " " + segment
    }
}
