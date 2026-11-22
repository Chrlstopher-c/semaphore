// Responsabilité : le texte qu'une session écrit en ce moment, côté présentation — cumul des deltas du flux par bloc
// (un bloc neuf repart de zéro : deux réponses séparées par un outil ne se collent pas) et rythme de révélation à
// l'écran (mot à mot, régulier même quand le réseau livre par paquets ; un retard se résorbe en douceur, ~1 s).

/// Le texte en cours d'écriture d'un fil, un bloc à la fois.
public struct CumulDirect: Sendable, Equatable {
    public private(set) var bloc: String
    public private(set) var texte: String

    public init(bloc: String, texte: String = "") {
        self.bloc = bloc
        self.texte = texte
    }

    /// Ajoute un delta ; un autre bloc remplace le texte (le précédent est fini, son texte final suit dans le fil).
    public mutating func ajouter(_ delta: String, bloc nouveau: String) {
        if nouveau == bloc {
            texte += delta
        } else {
            bloc = nouveau
            texte = delta
        }
    }
}

/// Le pas de révélation du texte en direct, appelé `cadence` fois par seconde par la vue.
public enum RythmeDirect {
    public static let cadence = 30
    /// Pas minimal : 2 caractères par pas, soit ~60 caractères par seconde quand le texte arrive au fil de l'eau.
    static let pasMinimal = 2
    /// Part du retard (texte reçu mais pas encore montré) rattrapée à chaque pas : 1/8, décroissance douce.
    static let pasDeRattrapage = 8
    /// Un mot entamé est fini d'un coup s'il lui reste au plus ce nombre de caractères : l'œil lit des mots entiers.
    static let finDeMotMax = 12

    /// Le nombre de caractères à montrer après ce pas, `affiches` l'étant déjà. Jamais plus que le texte reçu.
    public static func suivant(affiches: Int, dans texte: [Character]) -> Int {
        let total = texte.count
        guard affiches < total else { return total }
        let retard = total - affiches
        let pas = max(pasMinimal, retard / pasDeRattrapage)
        let cible = min(total, max(0, affiches) + pas)
        var fin = cible
        while fin < total, fin - cible < finDeMotMax, !texte[fin].isWhitespace { fin += 1 }
        return fin == total || texte[fin].isWhitespace ? fin : cible
    }

    /// Ce qui reste montré quand le texte change : tout ce qui est encore un début du nouveau texte, sinon rien.
    public static func conserve(affiches: Int, ancien: [Character], nouveau: [Character]) -> Int {
        let n = min(affiches, ancien.count, nouveau.count)
        return ancien.prefix(n) == nouveau.prefix(n) ? n : 0
    }
}
