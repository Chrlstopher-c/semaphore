import XCTest
@testable import EchoHubNoyau

/// Les cas repris de `frontend/src/chat/raisonnement/tests/extraction.test.ts`
/// d'EchoHub v2, plus ceux propres au téléphone. Deux implémentations qui
/// doivent découper au même endroit méritent la même batterie : c'est la seule
/// façon de savoir que la réponse lue au navigateur et celle lue sur l'iPhone
/// sont bien la même.
final class SegmenteurReponseTests: XCTestCase {

    func testTexteSansBaliseResteEntier() {
        let segmentee = SegmenteurReponse.segmenter("Bonjour.")
        XCTAssertEqual(segmentee.visible, "Bonjour.")
        XCTAssertTrue(segmentee.raisonnements.isEmpty)
        XCTAssertFalse(segmentee.enCours)
    }

    func testBlocComplet() {
        let segmentee = SegmenteurReponse.segmenter("<think>je réfléchis</think>Réponse.")
        XCTAssertEqual(segmentee.visible, "Réponse.")
        XCTAssertEqual(segmentee.raisonnements.map(\.texte), ["je réfléchis"])
        XCTAssertTrue(segmentee.raisonnements[0].complet)
    }

    /// Le cas du streaming en cours : la balise n'est pas encore refermée. Le
    /// raisonnement doit s'afficher QUAND MÊME, sinon l'écran reste vide
    /// pendant toute la réflexion du modèle.
    func testBlocJamaisReferme() {
        let segmentee = SegmenteurReponse.segmenter("début<think>coupé au milieu")
        XCTAssertEqual(segmentee.visible, "début")
        XCTAssertEqual(segmentee.raisonnements.map(\.texte), ["coupé au milieu"])
        XCTAssertFalse(segmentee.raisonnements[0].complet)
        XCTAssertTrue(segmentee.enCours)
    }

    func testPlusieursBlocsDansLOrdre() {
        let segmentee = SegmenteurReponse.segmenter("a<think>un</think>b<think>deux</think>c")
        XCTAssertEqual(segmentee.visible, "abc")
        XCTAssertEqual(segmentee.raisonnements.map(\.texte), ["un", "deux"])
        XCTAssertEqual(segmentee.raisonnements.map(\.id), [0, 1])
    }

    /// `☠` Le cas le plus important de tous, et le moins évident : les gabarits
    /// Qwen3 et DeepSeek-R1 amorcent eux-mêmes `<think>` dans le prompt. Le flux
    /// ne porte donc QUE la fermante. Sans ce traitement, la totalité du
    /// raisonnement s'affiche comme si c'était la réponse.
    func testFermetureOrphelineEstDuRaisonnement() {
        let segmentee = SegmenteurReponse.segmenter("je réfléchis</think>Réponse.")
        XCTAssertEqual(segmentee.visible, "Réponse.")
        XCTAssertEqual(segmentee.raisonnements.map(\.texte), ["je réfléchis"])
    }

    func testToutLeBudgetPasseEnRaisonnement() {
        let segmentee = SegmenteurReponse.segmenter("<think>tout est passé ici</think>")
        XCTAssertEqual(segmentee.visible, "")
        XCTAssertEqual(segmentee.raisonnements.count, 1)
    }

    func testBlocVide() {
        let segmentee = SegmenteurReponse.segmenter("<think></think>Réponse.")
        XCTAssertEqual(segmentee.visible, "Réponse.")
        XCTAssertEqual(segmentee.raisonnements.map(\.texte), [""])
    }

    func testAppelDuModeleReplie() {
        let source = #"Je cherche.<tool_call>{"name":"recherche_web"}</tool_call>Voilà."#
        let segmentee = SegmenteurReponse.segmenter(source)
        XCTAssertEqual(segmentee.visible, "Je cherche.Voilà.")
        XCTAssertEqual(segmentee.raisonnements.map(\.convention), ["appel"])
    }

    func testDialecteFunctionSansEnglobant() {
        let segmentee = SegmenteurReponse.segmenter("a<function=truc>{}</function>b")
        XCTAssertEqual(segmentee.visible, "ab")
        XCTAssertEqual(segmentee.raisonnements.map(\.convention), ["appel"])
    }

    /// Le commentaire de travail précède l'appel : il doit ressortir AVANT le
    /// bloc d'outil, pas après — sinon l'ordre affiché ment sur l'ordre réel.
    func testMarqueurDEtapeSepareLeCommentaireDeLaReponse() {
        let source = "Je vais chercher.<outil><entree>recherche_web(requete : météo)</entree>"
            + "<sortie>3 résultats</sortie></outil><etape-fin/>Il fait beau."
        let segmentee = SegmenteurReponse.segmenter(source)
        XCTAssertEqual(segmentee.visible, "Il fait beau.")
        XCTAssertEqual(segmentee.raisonnements.map(\.convention), ["etape", "outil"])
        XCTAssertEqual(segmentee.raisonnements[0].texte, "Je vais chercher.")
    }

    func testMarqueurDEtapeSansCommentaire() {
        let source = "<outil><entree>lire_fichier(chemin : a.txt)</entree><sortie>ok</sortie>"
            + "</outil><etape-fin/>Fait."
        let segmentee = SegmenteurReponse.segmenter(source)
        XCTAssertEqual(segmentee.visible, "Fait.")
        XCTAssertEqual(segmentee.raisonnements.map(\.convention), ["outil"])
    }

    /// Le cas constaté côté web le 2026-08-15 : le modèle referme son `</think>`
    /// APRÈS le résultat de l'outil. Sans comparaison de positions, le bloc
    /// d'outil se retrouvait avalé dans un segment « Raisonnement ».
    func testBlocOutilNEstPasAvaleParUneFermetureOrphelinePlusLoin() {
        let source = "<outil><entree>lire_fichier(chemin : a)</entree><sortie>ok</sortie>"
            + "</outil>puis je conclus</think>La réponse."
        let segmentee = SegmenteurReponse.segmenter(source)
        XCTAssertEqual(segmentee.visible, "La réponse.")
        XCTAssertEqual(segmentee.raisonnements.map(\.convention), ["outil", "think"])
    }

    func testChaineVide() {
        let segmentee = SegmenteurReponse.segmenter("")
        XCTAssertEqual(segmentee.visible, "")
        XCTAssertTrue(segmentee.raisonnements.isEmpty)
    }

    /// Invariant : rien ne se perd. Concaténer le visible et tous les blocs doit
    /// rendre autant de caractères que la source, balises déduites.
    func testRienNeDisparait() {
        let sources = [
            "simple",
            "<think>un</think>réponse",
            "a<think>un</think>b<think>deux</think>c",
            "début<think>jamais refermé",
            "<think>seulement du raisonnement</think>",
            "orpheline</think>suite",
        ]
        for source in sources {
            let segmentee = SegmenteurReponse.segmenter(source)
            let restitue = segmentee.visible.count
                + segmentee.raisonnements.reduce(0) { $0 + $1.texte.count }
            XCTAssertLessThanOrEqual(restitue, source.count, "source : \(source)")
            XCTAssertGreaterThan(restitue, 0, "source : \(source)")
        }
    }
}
