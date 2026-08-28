import Foundation

extension Passe {

    /// Une liste, à puces ou numérotée, avec ses niveaux d'imbrication et ses
    /// cases à cocher.
    ///
    /// `☠` Le moteur web mettait toutes les entrées au même rang : un plan à
    /// deux niveaux — la forme habituelle d'un rapport de lead — s'y lisait
    /// comme une liste plate, et la hiérarchie du raisonnement disparaissait.
    mutating func avalerListe(_ ligne: String) -> Bool {
        guard Self.entete(ligne) != nil else { return false }
        viderParagraphe()
        var entrees: [EntreeListe] = []
        while index < lignes.count {
            if let entete = Self.entete(lignes[index]) {
                entrees.append(Self.batir(entete))
                index += 1
            } else if let suite = Self.continuation(lignes[index]), let derniere = entrees.last {
                entrees[entrees.count - 1] = Self.prolonger(derniere, avec: suite)
                index += 1
            } else {
                break
            }
        }
        sortie.append(.liste(entrees: entrees))
        return true
    }

    // MARK: - Reconnaissance

    /// Ce qu'une ligne d'entrée porte, avant mise en forme.
    struct EnteteListe {
        let niveau: Int
        /// Numéro d'une liste ordonnée, `nil` pour une liste à puces.
        let numero: Int?
        let texte: String
    }

    /// `- texte`, `* texte`, `+ texte`, `3. texte`, `3) texte`.
    static func entete(_ ligne: String) -> EnteteListe? {
        let lettres = Array(ligne)
        var index = 0
        var retrait = 0
        while index < lettres.count, lettres[index] == " " || lettres[index] == "\t" {
            retrait += lettres[index] == "\t" ? 4 : 1
            index += 1
        }
        guard index < lettres.count else { return nil }
        if "-*+".contains(lettres[index]), index + 1 < lettres.count, lettres[index + 1] == " " {
            return EnteteListe(niveau: retrait / 2, numero: nil,
                               texte: String(lettres[(index + 2)...]).trimmingCharacters(in: .whitespaces))
        }
        return enteteNumerotee(lettres, depuis: index, retrait: retrait)
    }

    private static func enteteNumerotee(
        _ lettres: [Character],
        depuis depart: Int,
        retrait: Int
    ) -> EnteteListe? {
        var index = depart
        var chiffres = ""
        while index < lettres.count, lettres[index].isNumber, chiffres.count < 9 {
            chiffres.append(lettres[index])
            index += 1
        }
        guard !chiffres.isEmpty, index + 1 < lettres.count,
              lettres[index] == "." || lettres[index] == ")",
              lettres[index + 1] == " " else { return nil }
        return EnteteListe(
            niveau: retrait / 2,
            numero: Int(chiffres),
            texte: String(lettres[(index + 2)...]).trimmingCharacters(in: .whitespaces)
        )
    }

    /// Ligne de continuation : indentée, non vide, et qui n'ouvre pas d'entrée.
    /// C'est ce qui permet à une entrée de tenir sur deux lignes sans être
    /// coupée en deux puces.
    static func continuation(_ ligne: String) -> String? {
        guard entete(ligne) == nil else { return nil }
        let nu = ligne.trimmingCharacters(in: .whitespaces)
        guard !nu.isEmpty, ligne.hasPrefix("  ") else { return nil }
        return nu
    }

    // MARK: - Construction

    static func batir(_ entete: EnteteListe) -> EntreeListe {
        let (cochee, texte) = extraireCase(entete.texte)
        return EntreeListe(
            niveau: min(entete.niveau, 4),
            puce: puce(numero: entete.numero, niveau: entete.niveau),
            cochee: cochee,
            contenu: AnalyseurInline.analyser(texte)
        )
    }

    static func prolonger(_ entree: EntreeListe, avec suite: String) -> EntreeListe {
        EntreeListe(
            niveau: entree.niveau,
            puce: entree.puce,
            cochee: entree.cochee,
            contenu: entree.contenu + AnalyseurInline.analyser(" " + suite)
        )
    }

    /// Liste de tâches : `- [x] fait`. Rendue avec une vraie case, pas avec les
    /// crochets bruts que le moteur web laissait passer.
    private static func extraireCase(_ texte: String) -> (Bool?, String) {
        let minuscule = texte.lowercased()
        if minuscule.hasPrefix("[x] ") { return (true, String(texte.dropFirst(4))) }
        if minuscule.hasPrefix("[ ] ") { return (false, String(texte.dropFirst(4))) }
        return (nil, texte)
    }

    /// La puce est calculée ici et pas au rendu : la vue ne doit jamais avoir à
    /// savoir si la liste était numérotée.
    private static func puce(numero: Int?, niveau: Int) -> String {
        if let numero { return "\(numero)." }
        switch niveau {
        case 0: return "•"
        case 1: return "◦"
        default: return "▪"
        }
    }
}
