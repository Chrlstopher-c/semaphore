import XCTest
@testable import EchoHubNoyau

final class LectureAppelTests: XCTestCase {

    private let complet = "<entree>recherche_web(requete : météo à Lyon, langue : fr)</entree>"
        + "<sortie>6 résultats</sortie>"

    func testAppelConnuDonneLibelleIconeEtCible() {
        guard let appel = LectureAppel.lire(complet, actif: false) else {
            return XCTFail("appel attendu")
        }
        XCTAssertEqual(appel.nom, "recherche_web")
        XCTAssertEqual(appel.libelle, "Recherche web")
        XCTAssertEqual(appel.icone, .loupe)
        XCTAssertEqual(appel.cible, "météo à Lyon")
        XCTAssertEqual(appel.etat, .termine)
    }

    /// Un outil ajouté côté serveur sans mise à jour ici doit garder son nom
    /// technique exact. Inventer un libellé serait pire que ne rien traduire.
    func testOutilInconnuGardeSonNomBrut() {
        let texte = "<entree>outil_neuf(cible : x)</entree><sortie>ok</sortie>"
        guard let appel = LectureAppel.lire(texte, actif: false) else {
            return XCTFail("appel attendu")
        }
        XCTAssertEqual(appel.libelle, "outil_neuf")
        XCTAssertEqual(appel.icone, .outil)
        XCTAssertEqual(appel.cible, "cible : x")
    }

    func testSortieNonCloseEtGenerationActiveDonneEnCours() {
        let texte = "<entree>recherche_web(requete : météo)</entree><sortie>"
        XCTAssertEqual(LectureAppel.lire(texte, actif: true)?.etat, .enCours)
    }

    /// Sans génération en cours, une sortie jamais refermée est un appel coupé
    /// net. Le dire évite un « en cours » qui pulserait pour toujours.
    func testSortieNonCloseEtGenerationArreteeDonneInterrompu() {
        let texte = "<entree>recherche_web(requete : météo)</entree><sortie>"
        XCTAssertEqual(LectureAppel.lire(texte, actif: false)?.etat, .interrompu)
    }

    func testEchecPorteParLattributEtat() {
        let texte = "<entree>lire_fichier(chemin : absent.txt)</entree>"
            + "<sortie etat=\"echec\">fichier introuvable</sortie>"
        XCTAssertEqual(LectureAppel.lire(texte, actif: false)?.etat, .echec)
    }

    /// La forme sans attribut est celle de tous les messages écrits avant le
    /// 26/08/2026 : un historique relu ne doit pas changer d'apparence.
    func testFormeAncienneSansAttributResteLisible() {
        let texte = "<entree>lire_fichier(chemin : a.txt)</entree><sortie>contenu</sortie>"
        XCTAssertEqual(LectureAppel.lire(texte, actif: false)?.etat, .termine)
    }

    func testAliasDeCleReconnu() {
        let texte = "<entree>lister_fichiers(pattern : *.swift)</entree><sortie>3</sortie>"
        XCTAssertEqual(LectureAppel.lire(texte, actif: false)?.cible, "*.swift")
    }

    func testTexteSansBaliseNEstPasUnAppel() {
        XCTAssertNil(LectureAppel.lire("juste du texte", actif: false))
    }

    func testEntreeVideNEstPasUnAppel() {
        XCTAssertNil(LectureAppel.lire("<entree></entree><sortie>x</sortie>", actif: false))
    }

    func testParentheseTronqueeParLapercuServeur() {
        let texte = "<entree>ecrire_fichier(chemin : page.txt, contenu : bonjo</entree>"
        XCTAssertEqual(LectureAppel.lire(texte, actif: true)?.cible, "page.txt")
    }
}

final class CodageJSONTests: XCTestCase {

    /// `☠` La raison d'être de `CodageJSON` : `.iso8601` refuse les fractions
    /// de seconde, que pydantic écrit toujours. Un `.iso8601` naïf ferait
    /// échouer le décodage de TOUTE la liste des conversations.
    ///
    /// `☠` Les deux premières formes sont RELEVÉES sur le serveur réel le
    /// 26/08/2026 (`GET /api/chat/conversations`), pas imaginées — et c'est la
    /// différence qui compte : le serveur écrit un `Z` final, là où j'avais
    /// d'abord écrit `+00:00` dans ce test. Les deux passent, mais je ne le
    /// savais pas ; un test qui n'éprouve que des formes inventées est vert
    /// quoi qu'il arrive. Les suivantes restent couvertes parce que
    /// `datetime.isoformat()` les produit selon que le `datetime` porte un
    /// fuseau et des microsecondes.
    func testLesFormesReellementEmisesParPydantic() {
        let formes = [
            "2026-08-26T12:57:09.259149Z",   // relevé sur le serveur
            "2026-08-26T13:14:03.103157Z",   // relevé sur le serveur
            "2026-08-26T06:22:31.123456+00:00",
            "2026-08-26T06:22:31+00:00",
            "2026-08-26T06:22:31.123456",
            "2026-08-26T06:22:31",
        ]
        for forme in formes {
            XCTAssertNotNil(CodageJSON.dateDepuis(forme), "forme : \(forme)")
        }
    }

    /// Décodage d'une charge à la FORME exacte relevée sur le serveur : mêmes
    /// clés, même ordre, mêmes types. Les valeurs sont neutres — le dépôt n'a
    /// pas à porter les titres de conversation de Chris pour prouver un
    /// décodeur.
    func testDecodageALaFormeExacteDuServeur() throws {
        let charge = """
        [{"id":"018f-aaaa","titre":"Essai","modele_id":"depot/modele::fichier.gguf",\
        "cree_le":"2026-08-26T12:57:09.259149Z","maj_le":"2026-08-26T13:14:03.103157Z",\
        "archivee":false,"nb_messages":12}]
        """
        let liste = try CodageJSON.decodeur()
            .decode([ResumeConversation].self, from: Data(charge.utf8))
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste[0].nbMessages, 12)
        XCTAssertLessThan(liste[0].creeLe, liste[0].majLe)
    }

    func testFormeInconnueRendNil() {
        XCTAssertNil(CodageJSON.dateDepuis("hier soir"))
    }

    func testDecodageDUnResumeDeConversation() throws {
        let charge = """
        {"id":"c1","titre":"Essai","modele_id":"qwen","cree_le":"2026-08-26T06:22:31.123456",\
        "maj_le":"2026-08-26T06:30:00.000000","archivee":false,"nb_messages":4}
        """
        let resume = try CodageJSON.decodeur()
            .decode(ResumeConversation.self, from: Data(charge.utf8))
        XCTAssertEqual(resume.titre, "Essai")
        XCTAssertEqual(resume.nbMessages, 4)
        XCTAssertEqual(resume.modeleId, "qwen")
    }
}

final class ClientEchoHubTests: XCTestCase {

    /// `☠` Le piège qui produirait un 404 sur une route qui existe :
    /// `appendingPathComponent` pourcent-encode le `?` d'une requête.
    func testLaRequeteResteDuCoteRequeteEtPasDuCoteChemin() {
        let base = URL(string: "https://exemple.test")!
        let url = ClientEchoHub.url(base: base, chemin: "chat/conversations?archivees=true")
        XCTAssertEqual(url?.absoluteString, "https://exemple.test/api/chat/conversations?archivees=true")
    }

    func testCheminSansRequete() {
        let base = URL(string: "http://10.0.0.2:8947")!
        let url = ClientEchoHub.url(base: base, chemin: "inference/etat")
        XCTAssertEqual(url?.absoluteString, "http://10.0.0.2:8947/api/inference/etat")
    }

    func testAdresseSansSchemaEstInvalide() {
        XCTAssertFalse(ReglagesRelais(adresse: "10.0.0.2:8947", jeton: "").adresseValide)
        XCTAssertTrue(ReglagesRelais(adresse: "http://10.0.0.2:8947", jeton: "").adresseValide)
        XCTAssertTrue(ReglagesRelais(adresse: "https://exemple.test", jeton: "").adresseValide)
    }
}
