import Foundation

/// Le rendu markdown de Vigie, étage BLOCS.
///
/// `☠` Écrit à la main, et c'est une contrainte : `AttributedString(markdown:)`
/// ne connaît que l'inline, et aucune bibliothèque tierce n'entre dans une app
/// signée en provisionnement libre (chaque dépendance ajoute un binaire à
/// resigner à chaque déploiement). Le front web a le même moteur maison, pour
/// la même raison de souveraineté.
///
/// Ce qu'il rend, et que Safari rendait déjà : titres, listes, tableaux, blocs
/// de code. Ce qu'il rend en plus : les alignements de colonnes, les listes de
/// tâches, les citations, l'imbrication des listes et les liens.
public enum AnalyseurMarkdown {

    /// Analyse complète. Rendue idempotente et pure : c'est ce qui la rend
    /// testable sur Arch, sans téléphone.
    public static func analyser(_ source: String) -> [BlocMarkdown] {
        var passe = Passe(source: source)
        passe.derouler()
        return passe.sortie
    }

    /// Même analyse, numérotée pour `ForEach`.
    public static func blocs(_ source: String) -> [BlocRange] {
        analyser(source).enumerated().map { BlocRange(id: $0.offset, bloc: $0.element) }
    }
}

/// L'état d'une analyse en cours. Une structure plutôt qu'un tas de paramètres :
/// chaque règle consomme des lignes et pousse des blocs, et aucune n'a besoin
/// d'autre chose.
struct Passe {
    let lignes: [String]
    var index = 0
    var paragraphe: [String] = []
    var sortie: [BlocMarkdown] = []

    init(source: String) {
        lignes = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    mutating func derouler() {
        while index < lignes.count {
            let ligne = lignes[index]
            if avalerCode(ligne) { continue }
            if avalerTableau(ligne) { continue }
            if avalerTitre(ligne) { continue }
            if avalerSoulignement(ligne) { continue }
            if avalerFilet(ligne) { continue }
            if avalerCitation(ligne) { continue }
            if avalerListe(ligne) { continue }
            if ligne.trimmingCharacters(in: .whitespaces).isEmpty {
                viderParagraphe()
                index += 1
                continue
            }
            paragraphe.append(ligne)
            index += 1
        }
        viderParagraphe()
    }

    mutating func viderParagraphe() {
        guard !paragraphe.isEmpty else { return }
        // Les retours simples d'un paragraphe sont des retours de MISE EN PAGE,
        // pas des sauts de ligne : le modèle écrit en lignes de 80 colonnes et
        // les respecter hacherait le texte au milieu des phrases.
        let texte = paragraphe.joined(separator: " ")
        paragraphe = []
        sortie.append(.paragraphe(AnalyseurInline.analyser(texte)))
    }

    // MARK: - Blocs de code

    /// `☠` Une clôture jamais refermée n'est PAS une erreur : c'est l'état
    /// normal d'un bloc de code pendant que l'orchestrateur l'écrit, jeton par
    /// jeton. Le rendre comme du texte brut ferait clignoter le fil entre deux
    /// formes à chaque sondage.
    mutating func avalerCode(_ ligne: String) -> Bool {
        let nu = ligne.trimmingCharacters(in: .whitespaces)
        guard nu.hasPrefix("```") || nu.hasPrefix("~~~") else { return false }
        viderParagraphe()
        let marque = String(nu.prefix(3))
        let langage = String(nu.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var corps: [String] = []
        index += 1
        var referme = false
        while index < lignes.count {
            let courante = lignes[index].trimmingCharacters(in: .whitespaces)
            if courante.hasPrefix(marque) { referme = true; index += 1; break }
            corps.append(lignes[index])
            index += 1
        }
        sortie.append(.code(
            langage: langage.isEmpty ? nil : langage,
            texte: corps.joined(separator: "\n"),
            ouvert: !referme
        ))
        return true
    }

    // MARK: - Titres et séparateurs

    mutating func avalerTitre(_ ligne: String) -> Bool {
        let nu = ligne.trimmingCharacters(in: .whitespaces)
        let diese = nu.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(diese) else { return false }
        let reste = String(nu.dropFirst(diese))
        guard reste.isEmpty || reste.hasPrefix(" ") else { return false }
        viderParagraphe()
        let texte = reste.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        sortie.append(.titre(niveau: diese, contenu: AnalyseurInline.analyser(texte)))
        index += 1
        return true
    }

    /// Titre souligné (`Titre` puis `===` ou `---`). Absent du moteur web, et
    /// pourtant produit par plusieurs modèles : sans lui, la ligne de tirets
    /// s'affichait en filet juste sous un paragraphe orphelin.
    mutating func avalerSoulignement(_ ligne: String) -> Bool {
        guard !paragraphe.isEmpty else { return false }
        let nu = ligne.trimmingCharacters(in: .whitespaces)
        guard nu.count >= 2 else { return false }
        let egal = nu.allSatisfy { $0 == "=" }
        let tiret = nu.allSatisfy { $0 == "-" }
        guard egal || tiret else { return false }
        let texte = paragraphe.joined(separator: " ")
        paragraphe = []
        sortie.append(.titre(niveau: egal ? 1 : 2, contenu: AnalyseurInline.analyser(texte)))
        index += 1
        return true
    }

    mutating func avalerFilet(_ ligne: String) -> Bool {
        let nu = ligne.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "")
        guard nu.count >= 3 else { return false }
        let marques: Set<Character> = ["-", "*", "_"]
        guard let premiere = nu.first, marques.contains(premiere),
              nu.allSatisfy({ $0 == premiere }) else { return false }
        viderParagraphe()
        sortie.append(.filet)
        index += 1
        return true
    }

    // MARK: - Citations

    mutating func avalerCitation(_ ligne: String) -> Bool {
        guard ligne.trimmingCharacters(in: .whitespaces).hasPrefix(">") else { return false }
        viderParagraphe()
        var morceaux: [String] = []
        while index < lignes.count {
            let nu = lignes[index].trimmingCharacters(in: .whitespaces)
            guard nu.hasPrefix(">") else { break }
            morceaux.append(String(nu.dropFirst()).trimmingCharacters(in: .whitespaces))
            index += 1
        }
        sortie.append(.citation(AnalyseurInline.analyser(morceaux.joined(separator: " "))))
        return true
    }
}
