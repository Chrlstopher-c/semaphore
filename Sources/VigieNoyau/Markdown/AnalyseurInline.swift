import Foundation

/// Analyse le balisage AU FIL du texte : code, gras, italique, barré, liens.
///
/// `☠` `AttributedString(markdown:)` ne sait faire QUE ça, et c'est pour cette
/// raison qu'il ne suffit pas : ni titres, ni listes, ni tableaux, ni blocs de
/// code. Ici on ne traite que l'étage inline — les blocs sont dans
/// `AnalyseurMarkdown`, qui rappelle celui-ci pour chaque ligne.
///
/// `☠` `_souligné_` N'EST PAS de l'italique dans ce produit. Les identifiants du
/// harness sont en `snake_case` (`creer_equipe`, `mon_autonomie`,
/// `mcp__ccremote-controle__lister_equipes`) et les traiter comme de l'emphase
/// mangerait la moitié des noms d'outils affichés dans le fil. Seule l'étoile
/// marque l'emphase.
public enum AnalyseurInline {

    /// Au-delà, on cesse de descendre : un texte volontairement pathologique
    /// (`***********`) ne doit pas faire exploser la pile sur le téléphone.
    private static let profondeurMax = 6

    public static func analyser(_ source: String) -> [FragmentTexte] {
        guard !source.isEmpty else { return [] }
        var sortie: [FragmentTexte] = []
        decouper(Array(source), styles: [], profondeur: 0, dans: &sortie)
        return fusionner(sortie)
    }

    // MARK: - Découpage

    private static func decouper(
        _ suite: [Character],
        styles: StyleInline,
        profondeur: Int,
        dans sortie: inout [FragmentTexte]
    ) {
        var tampon = ""
        var index = 0
        while index < suite.count {
            if let saut = echappement(suite, index) {
                tampon.append(suite[index + 1])
                index = saut
            } else if let (contenu, suivant) = codeInline(suite, index) {
                vider(&tampon, styles: styles, dans: &sortie)
                sortie.append(FragmentTexte(contenu, styles: styles.union(.code)))
                index = suivant
            } else if profondeur < profondeurMax,
                      let coupe = emphase(suite, index, styles: styles, profondeur: profondeur) {
                vider(&tampon, styles: styles, dans: &sortie)
                sortie.append(contentsOf: coupe.fragments)
                index = coupe.suivant
            } else if profondeur < profondeurMax,
                      let coupe = lien(suite, index, styles: styles, profondeur: profondeur) {
                vider(&tampon, styles: styles, dans: &sortie)
                sortie.append(contentsOf: coupe.fragments)
                index = coupe.suivant
            } else {
                tampon.append(suite[index])
                index += 1
            }
        }
        vider(&tampon, styles: styles, dans: &sortie)
    }

    private static func vider(
        _ tampon: inout String,
        styles: StyleInline,
        dans sortie: inout [FragmentTexte]
    ) {
        guard !tampon.isEmpty else { return }
        sortie.append(FragmentTexte(tampon, styles: styles))
        tampon = ""
    }

    // MARK: - Motifs

    /// Barre oblique d'échappement : `\*` écrit une étoile, il n'ouvre rien.
    private static func echappement(_ suite: [Character], _ index: Int) -> Int? {
        guard suite[index] == "\\", index + 1 < suite.count,
              "\\`*_~[]()#+-.!>|".contains(suite[index + 1]) else { return nil }
        return index + 2
    }

    /// Code inline à N accents graves, refermé par exactement N. La forme longue
    /// (` ``x`` `) existe pour écrire un accent grave dans du code.
    private static func codeInline(_ suite: [Character], _ index: Int) -> (String, Int)?  {
        guard suite[index] == "`" else { return nil }
        let ouverture = longueurSerie(suite, index, "`")
        var curseur = index + ouverture
        while curseur < suite.count {
            guard suite[curseur] == "`" else { curseur += 1; continue }
            let fermeture = longueurSerie(suite, curseur, "`")
            if fermeture == ouverture {
                let brut = String(suite[(index + ouverture)..<curseur])
                return (degarnir(brut), curseur + fermeture)
            }
            curseur += fermeture
        }
        return nil
    }

    /// Une espace de part et d'autre est un artifice d'écriture, pas du contenu.
    private static func degarnir(_ brut: String) -> String {
        guard brut.count > 2, brut.hasPrefix(" "), brut.hasSuffix(" ") else { return brut }
        return String(brut.dropFirst().dropLast())
    }

    private static func longueurSerie(_ suite: [Character], _ depart: Int, _ marque: Character) -> Int {
        var compte = 0
        var index = depart
        while index < suite.count, suite[index] == marque {
            compte += 1
            index += 1
        }
        return compte
    }

    // MARK: - Emphase

    private struct Coupe {
        let fragments: [FragmentTexte]
        let suivant: Int
    }

    /// `**gras**`, `*italique*`, `~~barré~~`. L'ordre de test compte : la marque
    /// double doit être reconnue avant la simple.
    private static func emphase(
        _ suite: [Character],
        _ index: Int,
        styles: StyleInline,
        profondeur: Int
    ) -> Coupe? {
        let marques: [(String, StyleInline)] = [("~~", .barre), ("**", .gras), ("*", .italique)]
        for (marque, style) in marques {
            guard commencePar(suite, index, marque),
                  let fin = fermeture(suite, apres: index + marque.count, marque: marque)
            else { continue }
            let interieur = Array(suite[(index + marque.count)..<fin])
            var fragments: [FragmentTexte] = []
            decouper(interieur, styles: styles.union(style), profondeur: profondeur + 1, dans: &fragments)
            return Coupe(fragments: fragments, suivant: fin + marque.count)
        }
        return nil
    }

    /// Cherche la marque fermante. Le contenu ne peut ni être vide ni commencer
    /// par une espace : sans cette règle, « 3 * 4 * 5 » deviendrait de l'italique.
    private static func fermeture(_ suite: [Character], apres depart: Int, marque: String) -> Int? {
        guard depart < suite.count, !suite[depart].isWhitespace else { return nil }
        var index = depart
        while index < suite.count {
            if suite[index] == "\\" { index += 2; continue }
            if commencePar(suite, index, marque), index > depart,
               !suite[index - 1].isWhitespace { return index }
            if suite[index] == "\n", index + 1 < suite.count, suite[index + 1] == "\n" { return nil }
            index += 1
        }
        return nil
    }

    private static func commencePar(_ suite: [Character], _ index: Int, _ marque: String) -> Bool {
        let lettres = Array(marque)
        guard index + lettres.count <= suite.count else { return false }
        for (decalage, lettre) in lettres.enumerated() where suite[index + decalage] != lettre {
            return false
        }
        return true
    }

    // MARK: - Liens

    /// `[libellé](cible)`. La cible est prise telle quelle : c'est la vue qui
    /// décide de ce qu'elle en fait, et elle seule sait ce qui est ouvrable.
    private static func lien(
        _ suite: [Character],
        _ index: Int,
        styles: StyleInline,
        profondeur: Int
    ) -> Coupe? {
        guard suite[index] == "[", let finLibelle = fermetureSimple(suite, apres: index + 1, "[", "]"),
              finLibelle + 1 < suite.count, suite[finLibelle + 1] == "(",
              let finCible = fermetureSimple(suite, apres: finLibelle + 2, "(", ")")
        else { return nil }
        let cible = String(suite[(finLibelle + 2)..<finCible]).trimmingCharacters(in: .whitespaces)
        guard !cible.isEmpty else { return nil }
        var interne: [FragmentTexte] = []
        decouper(Array(suite[(index + 1)..<finLibelle]), styles: styles,
                 profondeur: profondeur + 1, dans: &interne)
        let fragments = interne.map { FragmentTexte($0.texte, styles: $0.styles, lien: cible) }
        return Coupe(fragments: fragments, suivant: finCible + 1)
    }

    /// Fermeture d'une paire imbriquable — un lien vers une URL à parenthèses
    /// (Wikipédia en produit) ne doit pas être coupé sur la première.
    private static func fermetureSimple(
        _ suite: [Character],
        apres depart: Int,
        _ ouvrante: Character,
        _ fermante: Character
    ) -> Int? {
        var niveau = 1
        var index = depart
        while index < suite.count {
            let lettre = suite[index]
            if lettre == "\\" { index += 2; continue }
            if lettre == "\n" { return nil }
            if lettre == ouvrante { niveau += 1 }
            if lettre == fermante {
                niveau -= 1
                if niveau == 0 { return index }
            }
            index += 1
        }
        return nil
    }

    // MARK: - Fusion

    /// Recolle les fragments voisins de même style : la découpe caractère par
    /// caractère en produit naturellement des chaînes de longueur 1, et un `Text`
    /// par lettre coûterait cher pour rien sur A12.
    private static func fusionner(_ fragments: [FragmentTexte]) -> [FragmentTexte] {
        var sortie: [FragmentTexte] = []
        for fragment in fragments where !fragment.estVide {
            if let dernier = sortie.last, dernier.styles == fragment.styles, dernier.lien == fragment.lien {
                sortie[sortie.count - 1] = FragmentTexte(
                    dernier.texte + fragment.texte, styles: dernier.styles, lien: dernier.lien
                )
            } else {
                sortie.append(fragment)
            }
        }
        return sortie
    }
}
