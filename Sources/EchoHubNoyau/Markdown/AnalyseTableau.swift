import Foundation

/// La lecture des tableaux à barres verticales (convention GFM) — la forme
/// qu'émettent les modèles dès qu'on leur demande de comparer quoi que ce soit.
/// Portée de `frontend/src/chat/markdown/tableau.ts`.
///
/// `☠` Un tableau n'est reconnu que sur la présence de sa ligne de
/// DÉLIMITEURS, de même largeur que l'en-tête. Sans cette exigence, une phrase
/// contenant une barre verticale deviendrait un tableau — et c'est aussi ce qui
/// rend le streaming tolérable : tant que `|---|---|` n'est pas arrivée,
/// l'en-tête s'affiche comme du texte, puis se réorganise au fragment suivant.
///
/// `☠` Coût sur le chemin de génération, mesuré en complexité et non deviné :
/// `ReponseModele` réanalyse le markdown à chaque fragment. Ce module n'ajoute
/// qu'un test de DEUX lignes par début de bloc — deux découpes sur `|` et une
/// expression régulière par cellule de délimiteur, sur la seule ligne
/// `depart + 1`. Le corps du tableau n'est relu que si ce test passe. L'ordre
/// de grandeur du balayage reste O(n) par fragment, donc O(n²) sur un tour,
/// exactement comme avant ; la constante augmente d'un facteur de l'ordre du
/// nombre de blocs, pas du nombre de caractères.
enum AnalyseTableau {

    /// Une cellule de délimiteur : `---`, `:---`, `---:`, `:---:`.
    private static let motifDelimiteur = try? NSRegularExpression(pattern: "^:?-+:?$")

    /// Vrai si les lignes `depart` et `depart + 1` forment un en-tête suivi de
    /// ses délimiteurs, en même nombre de colonnes.
    static func estTableau(_ lignes: [String], _ depart: Int) -> Bool {
        let entete = AnalyseListe.ligne(lignes, depart)
        let delimiteurs = AnalyseListe.ligne(lignes, depart + 1)
        guard entete.contains("|"), delimiteurs.contains("|") else { return false }
        let colonnes = cellules(delimiteurs)
        guard !colonnes.isEmpty, colonnes.allSatisfy(estDelimiteur) else { return false }
        return cellules(entete).count == colonnes.count
    }

    /// Lit le tableau à partir de son en-tête. Le corps peut être VIDE — c'est
    /// l'état normal pendant le streaming, juste après l'arrivée des
    /// délimiteurs : on montre l'en-tête plutôt que rien.
    static func lire(
        _ lignes: [String], _ depart: Int
    ) -> (bloc: BlocMarkdown, suivant: Int) {
        let entetes = cellules(AnalyseListe.ligne(lignes, depart)).map(AnalyseInline.analyser)
        let alignements = cellules(AnalyseListe.ligne(lignes, depart + 1)).map(alignement)
        var corps: [[[SegmentInline]]] = []
        var i = depart + 2
        // Bornée : chaque tour consomme une ligne, et la première ligne non
        // conforme arrête la lecture.
        while i < lignes.count, estRangee(AnalyseListe.ligne(lignes, i)) {
            corps.append(normaliser(cellules(AnalyseListe.ligne(lignes, i)), entetes.count))
            i += 1
        }
        return (
            .tableau(TableauMarkdown(entetes: entetes, alignements: alignements, lignes: corps)),
            i
        )
    }

    /// Découpe une rangée en cellules. Les barres échappées (`\|`) restent du
    /// contenu — sans quoi une cellule qui parle d'un tube couperait la rangée.
    static func cellules(_ ligne: String) -> [String] {
        var nu = Substring(ligne.trimmingCharacters(in: .whitespaces))
        if nu.hasPrefix("|") { nu = nu.dropFirst() }
        if nu.hasSuffix("|") { nu = nu.dropLast() }
        return decouper(String(nu)).map {
            $0.replacingOccurrences(of: "\\|", with: "|")
                .trimmingCharacters(in: .whitespaces)
        }
    }

    /// Découpe sur les `|` NON précédées d'une contre-oblique. Écrit à la main
    /// plutôt qu'en expression régulière : `components(separatedBy:)` ne connaît
    /// pas l'échappement, et une régression rétrospective se paierait sur chaque
    /// rangée d'un tableau de code.
    private static func decouper(_ texte: String) -> [String] {
        var morceaux: [String] = []
        var courant = ""
        var echappe = false
        for caractere in texte {
            if echappe {
                courant.append(caractere)
                echappe = false
            } else if caractere == "\\" {
                courant.append(caractere)
                echappe = true
            } else if caractere == "|" {
                morceaux.append(courant)
                courant = ""
            } else {
                courant.append(caractere)
            }
        }
        morceaux.append(courant)
        return morceaux
    }

    private static func estDelimiteur(_ cellule: String) -> Bool {
        guard let motifDelimiteur else { return false }
        let entier = NSRange(cellule.startIndex..., in: cellule)
        return motifDelimiteur.firstMatch(in: cellule, range: entier) != nil
    }

    private static func alignement(_ delimiteur: String) -> Alignement {
        let gauche = delimiteur.hasPrefix(":")
        let droite = delimiteur.hasSuffix(":")
        if gauche, droite { return .centre }
        return droite ? .droite : .gauche
    }

    private static func estRangee(_ ligne: String) -> Bool {
        !ligne.trimmingCharacters(in: .whitespaces).isEmpty && ligne.contains("|")
    }

    /// Complète une rangée courte : une cellule manquante vaut vide, elle ne
    /// DÉCALE pas les colonnes. Pendant le streaming, la dernière rangée est
    /// presque toujours courte.
    private static func normaliser(
        _ brutes: [String], _ colonnes: Int
    ) -> [[SegmentInline]] {
        var rangee = brutes.map(AnalyseInline.analyser)
        while rangee.count < colonnes { rangee.append([]) }
        return rangee
    }
}
