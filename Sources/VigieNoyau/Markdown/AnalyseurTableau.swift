import Foundation

extension Passe {

    /// Un tableau : ligne d'entête, ligne de séparation, puis le corps.
    ///
    /// `☠` C'est le bloc qui justifie à lui seul d'avoir écrit un moteur. Un
    /// rapport de lead rend ses mesures en tableau ; sans ce cas, l'écran
    /// affiche des lignes de barres verticales — exactement ce que le fil
    /// montrait avant que le web ne se dote de son propre moteur.
    mutating func avalerTableau(_ ligne: String) -> Bool {
        guard ligne.trimmingCharacters(in: .whitespaces).hasPrefix("|"),
              index + 1 < lignes.count,
              let alignements = Self.separation(lignes[index + 1]) else { return false }
        viderParagraphe()
        let entete = Self.cellules(ligne).map(AnalyseurInline.analyser)
        index += 2
        var corps: [[[FragmentTexte]]] = []
        while index < lignes.count,
              lignes[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
            corps.append(Self.cellules(lignes[index]).map(AnalyseurInline.analyser))
            index += 1
        }
        sortie.append(.tableau(TableauMarkdown(
            entete: entete, alignements: alignements, lignes: corps
        )))
        return true
    }

    /// La ligne de séparation, qui porte aussi les alignements (`:---:`).
    /// `nil` = ce n'en est pas une, donc la ligne précédente n'était pas un
    /// entête et ne doit surtout pas être avalée comme tel.
    static func separation(_ ligne: String) -> [AlignementColonne]? {
        let nu = ligne.trimmingCharacters(in: .whitespaces)
        guard nu.hasPrefix("|") else { return nil }
        let colonnes = cellules(ligne)
        guard !colonnes.isEmpty else { return nil }
        var alignements: [AlignementColonne] = []
        for colonne in colonnes {
            let motif = colonne.replacingOccurrences(of: " ", with: "")
            guard motif.contains("-"),
                  motif.allSatisfy({ $0 == "-" || $0 == ":" }) else { return nil }
            alignements.append(alignement(motif))
        }
        return alignements
    }

    private static func alignement(_ motif: String) -> AlignementColonne {
        let gauche = motif.hasPrefix(":")
        let droite = motif.hasSuffix(":")
        if gauche && droite { return .centre }
        if droite { return .droite }
        return .gauche
    }

    /// Découpe une ligne en cellules.
    ///
    /// `☠` La barre échappée (`\|`) reste du CONTENU : un chemin ou une regex
    /// dans une cellule en contient, et couper dessus décalerait toute la ligne
    /// d'une colonne sans que rien ne le signale.
    static func cellules(_ ligne: String) -> [String] {
        var cellules: [String] = []
        var courante = ""
        var echappe = false
        for lettre in ligne.trimmingCharacters(in: .whitespaces) {
            if echappe {
                // Seule la barre est consommée ici ; les autres échappements
                // appartiennent à l'étage inline, qui les traitera après coup.
                courante.append(lettre == "|" ? "|" : "\\\(lettre)")
                echappe = false
            } else if lettre == "\\" {
                echappe = true
            } else if lettre == "|" {
                cellules.append(courante.trimmingCharacters(in: .whitespaces))
                courante = ""
            } else {
                courante.append(lettre)
            }
        }
        if echappe { courante.append("\\") }
        cellules.append(courante.trimmingCharacters(in: .whitespaces))
        return elaguer(cellules)
    }

    /// Retire les cellules vides de bord dues aux barres d'ouverture et de
    /// fermeture — sans toucher à une cellule vide LÉGITIME au milieu.
    private static func elaguer(_ cellules: [String]) -> [String] {
        var sortie = cellules
        if sortie.first?.isEmpty == true { sortie.removeFirst() }
        if sortie.last?.isEmpty == true { sortie.removeLast() }
        return sortie
    }
}
