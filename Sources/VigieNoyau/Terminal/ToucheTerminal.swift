import Foundation

/// Une touche que le clavier iOS n'a pas et dont un shell ne peut pas se passer.
///
/// `☠` CONTRAINTE DE LA ROUTE, à connaître avant de lire la suite : `POST
/// /api/send` n'envoie pas ce qu'on lui donne. Le serveur du poste fait
/// `tmux send-keys -l <keys>`, attend 200 ms, PUIS envoie `Enter`
/// (`server/server.py`, correctif bracketed-paste de Claude Code). **Tout envoi
/// se termine donc par une validation, sans exception possible côté client.**
///
/// Ce n'est pas rattrapable depuis Vigie : la seule parade serait de modifier
/// ccremote. On compose donc AVEC — et c'est jouable, parce que le cas d'usage
/// dominant est exactement celui-là : dans les dialogues de Claude Code, une
/// flèche suivie d'Entrée, c'est « choisir cette option ».
public struct ToucheTerminal: Sendable, Equatable, Identifiable {
    /// Le code émis par la barre d'accessoires de la charte.
    public let code: String
    public let libelle: String
    /// La suite d'octets à envoyer. Vide pour une touche modificatrice.
    public let sequence: String
    /// Ce que la touche fait vraiment une fois l'Entrée automatique ajoutée.
    public let effetReel: String

    public var id: String { code }

    public init(code: String, libelle: String, sequence: String, effetReel: String) {
        self.code = code
        self.libelle = libelle
        self.sequence = sequence
        self.effetReel = effetReel
    }

    /// Une touche sans séquence est un modificateur : elle arme la suivante au
    /// lieu de partir sur le fil.
    public var estModificateur: Bool { sequence.isEmpty }
}

extension ToucheTerminal {
    public static let echappement = ToucheTerminal(
        code: "esc",
        libelle: "Esc",
        sequence: "\u{1B}",
        effetReel: "annule la saisie en cours, puis valide une ligne vide"
    )
    public static let tabulation = ToucheTerminal(
        code: "tab",
        libelle: "⇥",
        sequence: "\t",
        effetReel: "complète, puis valide"
    )
    /// Modificateur : arme le contrôle pour le prochain caractère saisi.
    public static let controle = ToucheTerminal(
        code: "ctrl",
        libelle: "^",
        sequence: "",
        effetReel: "arme Ctrl pour la prochaine lettre tapée"
    )
    public static let haut = ToucheTerminal(
        code: "up", libelle: "↑", sequence: "\u{1B}[A",
        effetReel: "remonte d'un cran, puis valide le choix"
    )
    public static let bas = ToucheTerminal(
        code: "down", libelle: "↓", sequence: "\u{1B}[B",
        effetReel: "descend d'un cran, puis valide le choix"
    )
    public static let droite = ToucheTerminal(
        code: "right", libelle: "→", sequence: "\u{1B}[C",
        effetReel: "avance d'un caractère, puis valide"
    )
    public static let gauche = ToucheTerminal(
        code: "left", libelle: "←", sequence: "\u{1B}[D",
        effetReel: "recule d'un caractère, puis valide"
    )

    /// Les touches servies par `BarreTerminal` de la charte, dans son ordre.
    public static let toutes: [ToucheTerminal] = [
        .echappement, .tabulation, .controle, .haut, .bas, .gauche, .droite,
    ]

    public static func pour(code: String) -> ToucheTerminal? {
        toutes.first { $0.code == code }
    }

    /// `a` → `\u{01}`, `c` → `\u{03}`. `nil` hors de l'alphabet : Ctrl-7 et
    /// consorts existent mais ne se tapent pas sur un clavier iOS.
    public static func sequenceControle(_ lettre: Character) -> String? {
        let majuscule = Character(lettre.uppercased())
        guard let scalaire = majuscule.unicodeScalars.first,
              majuscule.unicodeScalars.count == 1,
              ("A"..."Z").contains(majuscule) else { return nil }
        guard let controle = Unicode.Scalar(scalaire.value - 64) else { return nil }
        return String(Character(controle))
    }

    /// Les raccourcis qu'on veut à portée de pouce sans passer par le clavier :
    /// interrompre, sortir, effacer la ligne.
    public static let raccourcisFrequents: [(libelle: String, lettre: Character, effet: String)] = [
        ("^C", "c", "interrompt le processus au premier plan"),
        ("^D", "d", "ferme l'entrée — quitte le shell si la ligne est vide"),
        ("^U", "u", "efface la ligne saisie"),
        ("^L", "l", "nettoie l'écran"),
    ]
}
