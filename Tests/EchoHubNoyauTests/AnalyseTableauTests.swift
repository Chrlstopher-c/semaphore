import XCTest
@testable import EchoHubNoyau

/// Les cas de tableaux de `frontend/src/chat/markdown/tests/parseur.test.ts`,
/// portés tels quels, plus ce que le streaming impose.
///
/// `☠` Deux implémentations qui doivent découper au même endroit méritent les
/// mêmes cas : sinon un tableau lu au navigateur et le même lu sur l'iPhone
/// divergent sans que personne ne le voie.
final class AnalyseTableauTests: XCTestCase {

    private func tableau(_ source: String, _ index: Int = 0) throws -> TableauMarkdown {
        let blocs = AnalyseMarkdown.analyser(source)
        let trouve = try XCTUnwrap(
            blocs.indices.contains(index) ? blocs[index] : nil,
            "bloc \(index) absent — \(blocs.count) bloc(s)"
        )
        guard case .tableau(let lu) = trouve.bloc else {
            throw XCTSkip("bloc \(index) n'est pas un tableau : \(trouve.bloc)")
        }
        return lu
    }

    private func brut(_ segments: [SegmentInline]) -> String {
        segments.map(\.brut).joined()
    }

    // MARK: - Les cas du navigateur

    func testTableauReconnuAvecSesAlignementsEtSesRangees() throws {
        let lu = try tableau("| Modèle | VRAM |\n|:---|---:|\n| A | 10 |\n| B | 12 |")
        XCTAssertEqual(lu.alignements, [.gauche, .droite])
        XCTAssertEqual(lu.entetes.map(brut), ["Modèle", "VRAM"])
        XCTAssertEqual(lu.lignes.count, 2)
        XCTAssertEqual(lu.lignes.first.map { $0.map(brut) }, ["A", "10"])
    }

    /// L'état normal juste après l'arrivée des délimiteurs : on montre l'en-tête
    /// plutôt que rien. Un tableau vide n'est pas un tableau cassé.
    func testUnTableauSansRangeeEstUnTableauPendantLeStreaming() throws {
        XCTAssertEqual(try tableau("| a | b |\n|---|---|").lignes.count, 0)
    }

    /// Une cellule manquante vaut vide : elle ne DÉCALE pas les colonnes. C'est
    /// le cas de la dernière rangée à presque chaque fragment reçu.
    func testUneRangeeCourteEstCompleteeALaLargeurDesColonnes() throws {
        let lu = try tableau("| a | b |\n|---|---|\n| 1")
        XCTAssertEqual(lu.lignes.first?.count, 2)
        XCTAssertEqual(lu.lignes.first.map { $0.map(brut) }, ["1", ""])
    }

    /// `☠` La ligne de délimiteurs est la SEULE preuve qu'un tableau commence.
    /// Sans cette exigence, toute phrase contenant une barre verticale
    /// deviendrait une grille d'une colonne.
    func testUneBarreVerticaleSeuleNeFaitPasUnTableau() {
        let blocs = AnalyseMarkdown.analyser("un texte | avec une barre\nsuite")
        guard case .paragraphe = blocs.first?.bloc else {
            return XCTFail("une barre isolée a été prise pour un tableau")
        }
    }

    // MARK: - Ce que le portage doit tenir en plus

    func testAlignementCentreLuDansSesDeuxPointsPoints() throws {
        let lu = try tableau("| a | b | c |\n|:---:|---:|---|\n| 1 | 2 | 3 |")
        XCTAssertEqual(lu.alignements, [.centre, .droite, .gauche])
    }

    /// Un nombre de délimiteurs différent du nombre d'en-têtes n'est pas un
    /// tableau : c'est du texte qui y ressemble.
    func testLesLargeursQuiNeSeCorrespondentPasNeFontPasUnTableau() {
        let blocs = AnalyseMarkdown.analyser("| a | b |\n|---|\n| 1 | 2 |")
        guard case .paragraphe = blocs.first?.bloc else {
            return XCTFail("un en-tête et des délimiteurs de largeurs différentes ont été acceptés")
        }
    }

    /// `☠` Une barre échappée reste du CONTENU. Sans elle, une cellule qui parle
    /// d'un tube (`a \\| b`) couperait la rangée en deux et décalerait tout ce
    /// qui suit sur la ligne.
    func testUneBarreEchappeeResteDuContenu() throws {
        let lu = try tableau("| commande | effet |\n|---|---|\n| ls \\| wc | compte |")
        XCTAssertEqual(lu.lignes.first?.count, 2)
        XCTAssertEqual(lu.lignes.first.map { $0.map(brut) }, ["ls | wc", "compte"])
    }

    func testLInlineEstAnalyseDansLesCellules() throws {
        let lu = try tableau("| **gras** | `code` |\n|---|---|\n| a | b |")
        guard case .fort(let texte) = lu.entetes.first?.first else {
            return XCTFail("l'inline n'a pas été analysé dans une en-tête")
        }
        XCTAssertEqual(texte, "gras")
    }

    /// Un tableau posé juste après une phrase doit être vu : la détection tient
    /// à la ligne de délimiteurs, donc `estDebutDeBloc` doit regarder DEUX
    /// lignes. Sans ça, le paragraphe avale l'en-tête et la grille disparaît.
    func testUnTableauCollePartUnParagrapheEstQuandMemeVu() throws {
        let blocs = AnalyseMarkdown.analyser("Voici la comparaison :\n| a | b |\n|---|---|\n| 1 | 2 |")
        XCTAssertEqual(blocs.count, 2)
        guard case .paragraphe = blocs.first?.bloc else {
            return XCTFail("la phrase d'introduction n'est plus un paragraphe")
        }
        _ = try tableau("Voici la comparaison :\n| a | b |\n|---|---|\n| 1 | 2 |", 1)
    }

    /// Le tableau passe AVANT la liste : une rangée qui commence par un tiret de
    /// délimiteur ne doit pas être lue comme un item.
    func testLeTableauEstLuAvantLaListe() throws {
        let lu = try tableau("| a | b |\n| --- | --- |\n| - x | - y |")
        XCTAssertEqual(lu.lignes.count, 1)
    }

    /// Ce qui vient après le tableau reste lisible : la lecture s'arrête à la
    /// première ligne sans barre.
    func testLaLectureSArreteALaPremiereLigneSansBarre() throws {
        let source = "| a |\n|---|\n| 1 |\n\nUn paragraphe après."
        XCTAssertEqual(try tableau(source).lignes.count, 1)
        let blocs = AnalyseMarkdown.analyser(source)
        XCTAssertEqual(blocs.count, 2)
        guard case .paragraphe(let contenu) = blocs.last?.bloc else {
            return XCTFail("le texte qui suit le tableau a disparu")
        }
        XCTAssertEqual(brut(contenu), "Un paragraphe après.")
    }
}
