import Foundation

/// L'analyse Markdown, calibrée sur ce qu'écrit réellement un modèle : titres,
/// listes imbriquées, citations, blocs de code, séparateurs, et l'inline
/// courant. Portée de `frontend/src/chat/markdown/parseur.ts`.
///
/// `☠` Portée plutôt que réécrite, et avec sa batterie : deux implémentations
/// qui doivent découper au même endroit méritent les mêmes cas, sinon la
/// réponse lue au navigateur et celle lue sur l'iPhone divergent sans que
/// personne ne le voie. Même discipline que `SegmenteurReponse`, et elle a déjà
/// payé une fois.
///
/// `☠` L'analyse TOLÈRE l'inachevé, parce que le texte arrive fragment par
/// fragment : une clôture manquante donne un bloc `complet: false`, un marqueur
/// inline ouvert ressort en texte. À aucun moment un texte déjà reçu ne
/// disparaît de l'écran parce que sa construction n'est pas terminée.
///
/// `☠` Les tableaux SONT portés depuis le 28/08/2026 (`AnalyseTableau`). La
/// version précédente les laissait retomber en paragraphe : une comparaison
/// demandée à un modèle arrivait en bouillie de barres verticales. Le rendu
/// tient sur 375 pt parce que c'est le TABLEAU qui défile horizontalement,
/// jamais la page.
public enum AnalyseMarkdown {
    public static let clotureCode = "```"

    private static let motifTitre = try? NSRegularExpression(pattern: "^(#{1,6})\\s+(.*)$")
    private static let motifCitation = try? NSRegularExpression(pattern: "^>\\s?(.*)$")
    private static let motifSeparateur = try? NSRegularExpression(
        pattern: "^(-{3,}|\\*{3,}|_{3,})$"
    )
    private static let niveauMax = 6

    public static func analyser(_ source: String) -> [BlocIndexe] {
        let lignes = source.components(separatedBy: "\n")
        var blocs: [BlocIndexe] = []
        var i = 0
        // Chaque itération consomme au moins une ligne : la boucle est bornée
        // par le nombre de lignes.
        while i < lignes.count {
            guard !AnalyseListe.ligne(lignes, i).trimmingCharacters(in: .whitespaces).isEmpty else {
                i += 1
                continue
            }
            let avance = lireBloc(lignes, i)
            blocs.append(BlocIndexe(id: blocs.count, bloc: avance.bloc))
            i = max(avance.suivant, i + 1)
        }
        return blocs
    }

    /// Ordre significatif : le séparateur passe AVANT la liste — `---` n'est pas
    /// un item vide — le tableau avant la liste et la citation — une rangée
    /// n'est ni l'un ni l'autre — et la citation avant le paragraphe.
    private static func lireBloc(
        _ lignes: [String], _ depart: Int
    ) -> (bloc: BlocMarkdown, suivant: Int) {
        let ligne = AnalyseListe.ligne(lignes, depart)
        if ligne.hasPrefix(clotureCode) { return lireCode(lignes, depart) }
        if let titre = lireTitre(ligne) { return (titre, depart + 1) }
        if correspond(motifSeparateur, ligne.trimmingCharacters(in: .whitespaces)) {
            return (.separateur, depart + 1)
        }
        if AnalyseTableau.estTableau(lignes, depart) {
            return AnalyseTableau.lire(lignes, depart)
        }
        if let marque = AnalyseListe.marque(ligne) {
            let lue = AnalyseListe.lire(
                lignes, depart: depart, indentation: marque.indentation, profondeur: 0
            )
            return (.liste(lue.liste), lue.suivant)
        }
        if correspond(motifCitation, ligne) { return lireCitation(lignes, depart) }
        return lireParagraphe(lignes, depart)
    }

    private static func lireTitre(_ ligne: String) -> BlocMarkdown? {
        guard let motifTitre else { return nil }
        let entier = NSRange(ligne.startIndex..., in: ligne)
        guard let trouve = motifTitre.firstMatch(in: ligne, range: entier) else { return nil }
        let dieses = groupe(trouve, 1, ligne)
        return .titre(
            niveau: min(dieses.count, niveauMax),
            contenu: AnalyseInline.analyser(groupe(trouve, 2, ligne))
        )
    }

    private static func lireCode(
        _ lignes: [String], _ depart: Int
    ) -> (bloc: BlocMarkdown, suivant: Int) {
        let ouverture = AnalyseListe.ligne(lignes, depart)
        let langage = String(ouverture.dropFirst(clotureCode.count))
            .trimmingCharacters(in: .whitespaces)
        var corps: [String] = []
        var i = depart + 1
        while i < lignes.count, !AnalyseListe.ligne(lignes, i).hasPrefix(clotureCode) {
            corps.append(AnalyseListe.ligne(lignes, i))
            i += 1
        }
        let complet = i < lignes.count
        return (
            .code(langage: langage, texte: corps.joined(separator: "\n"), complet: complet),
            complet ? i + 1 : i
        )
    }

    private static func lireCitation(
        _ lignes: [String], _ depart: Int
    ) -> (bloc: BlocMarkdown, suivant: Int) {
        var parties: [String] = []
        var i = depart
        while i < lignes.count, let motifCitation {
            let ligne = AnalyseListe.ligne(lignes, i)
            let entier = NSRange(ligne.startIndex..., in: ligne)
            guard let trouve = motifCitation.firstMatch(in: ligne, range: entier) else { break }
            parties.append(groupe(trouve, 1, ligne))
            i += 1
        }
        return (.citation(AnalyseInline.analyser(parties.joined(separator: " "))), i)
    }

    private static func lireParagraphe(
        _ lignes: [String], _ depart: Int
    ) -> (bloc: BlocMarkdown, suivant: Int) {
        var parties: [String] = []
        var i = depart
        while i < lignes.count {
            let ligne = AnalyseListe.ligne(lignes, i)
            guard !ligne.trimmingCharacters(in: .whitespaces).isEmpty,
                  !estDebutDeBloc(lignes, i) else { break }
            parties.append(ligne.trimmingCharacters(in: .whitespaces))
            i += 1
        }
        return (.paragraphe(AnalyseInline.analyser(parties.joined(separator: " "))), i)
    }

    /// Un paragraphe s'arrête là où un autre bloc commence.
    ///
    /// `☠` Le tableau se teste sur DEUX lignes : sa détection tient à la ligne
    /// de délimiteurs, pas à la ligne courante seule. Sans ce cas, un tableau
    /// posé juste après une phrase serait avalé par le paragraphe qui précède.
    private static func estDebutDeBloc(_ lignes: [String], _ index: Int) -> Bool {
        let ligne = AnalyseListe.ligne(lignes, index)
        return ligne.hasPrefix(clotureCode)
            || correspond(motifTitre, ligne)
            || correspond(motifCitation, ligne)
            || correspond(motifSeparateur, ligne.trimmingCharacters(in: .whitespaces))
            || AnalyseListe.marque(ligne) != nil
            || AnalyseTableau.estTableau(lignes, index)
    }

    private static func correspond(_ motif: NSRegularExpression?, _ texte: String) -> Bool {
        guard let motif else { return false }
        let entier = NSRange(texte.startIndex..., in: texte)
        return motif.firstMatch(in: texte, range: entier) != nil
    }

    private static func groupe(
        _ trouve: NSTextCheckingResult, _ rang: Int, _ source: String
    ) -> String {
        guard let plage = Range(trouve.range(at: rang), in: source) else { return "" }
        return String(source[plage])
    }
}
