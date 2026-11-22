import Foundation

// Responsabilité : découper le texte de Claude qui s'écrit (deltas) en morceaux prêts à dire, dès qu'un morceau est
// complet. Le tout premier morceau d'une réponse part dès sa première virgule (premier son au plus tôt), les
// suivants à chaque fin de phrase. Le markdown est retiré (une voix le lit mal). Pur, testé sous Linux.

public struct DecoupePhrases: Sendable, Equatable {
    static let minimum = 18
    static let maximum = 220
    static let premierMinimum = 12
    static let abreviations = ["M.", "Mme.", "etc.", "cf.", "p.", "ex.", "St.", "Dr."]

    /// Bloc de texte en cours (un autre bloc = la suite de la réponse après un outil).
    public private(set) var bloc: String?
    /// Texte reçu du bloc en cours (brut), pour retrouver le reste quand le texte final arrive.
    public private(set) var recu = ""
    private var tampon = ""
    private var attente = ""
    private var premierFait = false

    public init() {}

    /// Un delta du bloc `bloc` → les morceaux devenus complets. Un nouveau bloc termine le précédent.
    public mutating func ajouter(_ delta: String, bloc nouveau: String) -> [String] {
        var sorties: [String] = []
        if bloc != nouveau {
            sorties += finirBloc()
            bloc = nouveau
        }
        recu += delta
        tampon += delta
        while let morceau = extraire() { sorties += accumuler(morceau) }
        return sorties
    }

    /// Le texte final d'un bloc est arrivé : ce qui n'a pas été reçu en direct part avec le reste du tampon.
    public mutating func finir(texteFinal: String?) -> [String] {
        if let final = texteFinal, final.count > recu.count, final.hasPrefix(recu) {
            tampon += String(final.dropFirst(recu.count))
        } else if let final = texteFinal, recu.isEmpty {
            tampon = final
        }
        return finirBloc()
    }

    /// Fin du tour : la prochaine réponse repart avec un premier morceau court.
    public mutating func nouveauTour() {
        self = DecoupePhrases()
    }

    private mutating func finirBloc() -> [String] {
        let reste = Self.nettoyer("\(attente) \(tampon)")
        attente = ""
        tampon = ""
        recu = ""
        bloc = nil
        guard reste.contains(where: { $0.isLetter || $0.isNumber }) else { return [] }
        premierFait = true
        return [reste]
    }

    private mutating func extraire() -> String? {
        if let fin = finDePhrase() { return couper(a: fin) }
        if !premierFait, let virgule = virgule(apres: Self.premierMinimum) { return couper(a: virgule) }
        if tampon.count > Self.maximum, let virgule = virgule(apres: Self.minimum) { return couper(a: virgule) }
        return nil
    }

    private mutating func couper(a index: String.Index) -> String {
        let morceau = String(tampon[..<index])
        tampon = String(tampon[index...])
        return morceau
    }

    /// Fin de phrase suivie d'un espace (la phrase est donc finie), hors abréviation.
    private func finDePhrase() -> String.Index? {
        var i = tampon.startIndex
        while i < tampon.endIndex {
            let c = tampon[i]
            let suivant = tampon.index(after: i)
            if ".!?…".contains(c), suivant < tampon.endIndex, tampon[suivant].isWhitespace || tampon[suivant] == "\n",
               !finitParAbreviation(tampon[..<suivant]) {
                return suivant
            }
            i = suivant
        }
        return nil
    }

    private func virgule(apres minimum: Int) -> String.Index? {
        guard tampon.count > minimum else { return nil }
        let debut = tampon.index(tampon.startIndex, offsetBy: minimum)
        guard let r = tampon.range(of: ", ", range: debut..<tampon.endIndex) else { return nil }
        return tampon.index(after: r.lowerBound)
    }

    private func finitParAbreviation(_ texte: Substring) -> Bool {
        let mots = texte.split(whereSeparator: \.isWhitespace)
        guard let dernier = mots.last else { return false }
        return Self.abreviations.contains(String(dernier))
    }

    private mutating func accumuler(_ morceau: String) -> [String] {
        let texte = Self.nettoyer("\(attente) \(morceau)")
        let minimum = premierFait ? Self.minimum : Self.premierMinimum
        if texte.count < minimum {
            attente = texte
            return []
        }
        attente = ""
        premierFait = true
        return texte.isEmpty ? [] : [texte]
    }

    /// Retire ce qu'une voix lit mal : marques markdown, puces, titres, code, liens, espaces multiples.
    public static func nettoyer(_ texte: String) -> String {
        var t = texte
        for (motif, remplacement) in [
            (#"```[\s\S]*?```"#, " "), (#"\[([^\]]+)\]\([^)]+\)"#, "$1"), (#"(\*\*|__|\*|`|~~)"#, ""),
            (#"(?m)^\s*#+\s*"#, ""), (#"(?m)^\s*([-•*]|\d+\.)\s+"#, ""), (#"\s+"#, " "),
        ] {
            t = t.replacingOccurrences(of: motif, with: remplacement, options: .regularExpression)
        }
        return t.trimmingCharacters(in: .whitespaces)
    }
}
