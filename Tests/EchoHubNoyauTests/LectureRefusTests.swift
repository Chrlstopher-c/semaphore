import XCTest
@testable import EchoHubNoyau

/// Le mappage des refus est la seule règle du noyau qui se teste sans réseau ET
/// dont une erreur produit un mensonge affiché : avant ces cas, un `409` de la
/// route `chat` — « une génération est déjà en cours » — rendait « Aucun modèle
/// chargé sur le PC », c'est-à-dire l'inverse exact de ce qui se passait.
final class LectureRefusTests: XCTestCase {

    private func corps(_ json: String) -> Data { Data(json.utf8) }

    // MARK: - Le code fait foi, pas le statut

    func test409DeGenerationDejaEnCoursNestPasUnModeleAbsent() {
        let donnees = corps("""
        {"detail":{"code":"generation_deja_en_cours",
        "message":"Une génération est déjà en cours.",
        "remediation":"Attendre la fin de la génération en cours."}}
        """)
        XCTAssertEqual(LectureRefus.erreur(statut: 409, donnees: donnees), .generationEnCours)
    }

    func test503DeMoteurIndisponibleEstUnModeleAbsent() {
        let donnees = corps("""
        {"detail":{"code":"moteur_indisponible","message":"Aucun moteur prêt.",
        "remediation":"Installer ou redémarrer le moteur."}}
        """)
        XCTAssertEqual(LectureRefus.erreur(statut: 503, donnees: donnees), .aucunModelePret)
    }

    /// La route `POST /api/inference/generer` lève un `409` brut avec ce code.
    /// L'app ne l'appelle pas, mais rien ne garantit qu'elle ne l'appellera
    /// jamais : le code reste routé au bon endroit.
    func testAucunModelePretResteReconnu() {
        let donnees = corps("""
        {"detail":{"code":"aucun_modele_pret","message":"Aucun modèle chargé.","remediation":""}}
        """)
        XCTAssertEqual(LectureRefus.erreur(statut: 409, donnees: donnees), .aucunModelePret)
    }

    func testJetonRefuseParLeRelais() {
        let donnees = corps("""
        {"detail":{"code":"jeton_refuse","message":"Jeton absent ou invalide.",
        "remediation":"Vérifie le jeton dans les réglages de l'app."}}
        """)
        XCTAssertEqual(LectureRefus.erreur(statut: 401, donnees: donnees), .refuse)
    }

    // MARK: - Ce que le serveur écrit arrive jusqu'à l'écran

    func testLeMessageEtLeRemedeDuServeurSontConserves() {
        let donnees = corps("""
        {"detail":{"code":"modele_introuvable","message":"EchoHub ne repond pas sur le PC.",
        "remediation":"Vérifie que le PC est allumé et qu'EchoHub v2 tourne."}}
        """)
        let erreur = LectureRefus.erreur(statut: 502, donnees: donnees)
        XCTAssertEqual(erreur.libelle, "EchoHub ne repond pas sur le PC.")
        XCTAssertEqual(erreur.remede, "Vérifie que le PC est allumé et qu'EchoHub v2 tourne.")
    }

    /// Le backend écrit toujours la clé `remediation`, parfois vide. Une chaîne
    /// vide affichée sous un message est une ligne blanche inexpliquée.
    func testUnRemedeVideEstUneAbsencePasUneChaineVide() {
        let donnees = corps("""
        {"detail":{"code":"erreur_persistance","message":"Écriture impossible.","remediation":""}}
        """)
        XCTAssertNil(LectureRefus.erreur(statut: 500, donnees: donnees).remede)
    }

    /// `HTTPException` nue de FastAPI : `detail` vaut une chaîne, pas un objet.
    func testDetailEnChaineNueResteLisible() {
        let erreur = LectureRefus.erreur(statut: 404, donnees: corps("{\"detail\":\"Not Found\"}"))
        XCTAssertEqual(erreur.libelle, "Not Found")
    }

    // MARK: - Les maillons qui n'écrivent pas de code

    func testUn401SansCorpsResteUnJetonRefuse() {
        XCTAssertEqual(LectureRefus.erreur(statut: 401, donnees: Data()), .refuse)
    }

    /// Un `409` sans code ne dit plus « aucun modèle » : l'app ne sait pas, et
    /// elle rend le nombre plutôt qu'une phrase fausse.
    func testUn409SansCodeNeDevineRien() {
        XCTAssertEqual(
            LectureRefus.erreur(statut: 409, donnees: Data()),
            .serveur(statut: 409, message: "", remede: nil)
        )
    }

    func testCorpsHTMLDunProxyNeCasseRien() {
        let donnees = corps("<html><body>502 Bad Gateway</body></html>")
        XCTAssertEqual(
            LectureRefus.erreur(statut: 502, donnees: donnees),
            .serveur(statut: 502, message: "", remede: nil)
        )
    }

    // MARK: - Le remède ne désigne plus un onglet qui n'existe pas

    func testLeRemedeDesigneUnOngletQuiExiste() {
        let remede = ErreurRelais.aucunModelePret.remede ?? ""
        XCTAssertTrue(remede.contains("Machine"))
        XCTAssertFalse(remede.contains("Modèles"))
    }

    func testLaGenerationEnCoursProposeDArreter() {
        XCTAssertEqual(
            ErreurRelais.generationEnCours.libelle,
            "Une réponse est déjà en cours sur cette conversation."
        )
        XCTAssertNotNil(ErreurRelais.generationEnCours.remede)
    }
}
