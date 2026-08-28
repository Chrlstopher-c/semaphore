import XCTest
@testable import EchoHubNoyau

/// Le flux est ce que Chris regarde. Ces cas sont ceux qui, s'ils cassaient,
/// donneraient soit un écran figé, soit des « � » au milieu d'une phrase.
final class AnalyseurSSETests: XCTestCase {

    private func octets(_ texte: String) -> [UInt8] { Array(texte.utf8) }

    func testUneTrameCompleteEstRendue() {
        var analyseur = AnalyseurSSE()
        let trames = analyseur.absorber(octets("event: fragment\ndata: {\"a\":1}\n\n"))
        XCTAssertEqual(trames.count, 1)
        XCTAssertEqual(trames[0].evenement, "fragment")
        XCTAssertEqual(trames[0].donnees, "{\"a\":1}")
    }

    func testRienTantQueLaLigneVideNEstPasArrivee() {
        var analyseur = AnalyseurSSE()
        XCTAssertTrue(analyseur.absorber(octets("event: fragment\ndata: {\"a\":1}\n")).isEmpty)
    }

    func testDeuxTramesDansUnSeulMorceau() {
        var analyseur = AnalyseurSSE()
        let trames = analyseur.absorber(octets("data: un\n\ndata: deux\n\n"))
        XCTAssertEqual(trames.map(\.donnees), ["un", "deux"])
    }

    func testTrameCoupeeEntreDeuxMorceaux() {
        var analyseur = AnalyseurSSE()
        XCTAssertTrue(analyseur.absorber(octets("event: frag")).isEmpty)
        XCTAssertTrue(analyseur.absorber(octets("ment\ndata: sa")).isEmpty)
        let trames = analyseur.absorber(octets("lut\n\n"))
        XCTAssertEqual(trames.count, 1)
        XCTAssertEqual(trames[0].evenement, "fragment")
        XCTAssertEqual(trames[0].donnees, "salut")
    }

    /// `☠` Le cas qui justifie un tampon d'OCTETS : un « é » fait deux octets,
    /// et un morceau réseau peut tomber entre les deux. Décoder chaque morceau
    /// isolément produirait un caractère de remplacement dans la réponse.
    func testCaractereUTF8CoupeEnDeux() {
        var analyseur = AnalyseurSSE()
        let complet = octets("data: réfléchi\n\n")
        let coupe = octets("data: r").count + 1
        XCTAssertTrue(analyseur.absorber(complet[..<coupe]).isEmpty)
        let trames = analyseur.absorber(complet[coupe...])
        XCTAssertEqual(trames.map(\.donnees), ["réfléchi"])
    }

    func testFinsDeLigneCRLFAcceptees() {
        var analyseur = AnalyseurSSE()
        let trames = analyseur.absorber(octets("event: fin\r\ndata: {}\r\n\r\n"))
        XCTAssertEqual(trames.count, 1)
        XCTAssertEqual(trames[0].evenement, "fin")
    }

    func testCommentaireIgnore() {
        var analyseur = AnalyseurSSE()
        XCTAssertTrue(analyseur.absorber(octets(": battement\n\n")).isEmpty)
    }

    func testLignesDataMultiplesRecolleesParSautDeLigne() {
        var analyseur = AnalyseurSSE()
        let trames = analyseur.absorber(octets("data: un\ndata: deux\n\n"))
        XCTAssertEqual(trames.map(\.donnees), ["un\ndeux"])
    }

    /// Un serveur coupé net ne doit pas faire perdre le dernier fragment reçu.
    func testTrameResiduelleRendueParTerminer() {
        var analyseur = AnalyseurSSE()
        XCTAssertTrue(analyseur.absorber(octets("data: dernier")).isEmpty)
        XCTAssertEqual(analyseur.terminer()?.donnees, "dernier")
    }

    func testTerminerSansResiduRendNil() {
        var analyseur = AnalyseurSSE()
        _ = analyseur.absorber(octets("data: un\n\n"))
        XCTAssertNil(analyseur.terminer())
    }
}

final class LectureEvenementTests: XCTestCase {

    private func lire(_ donnees: String, evenement: String? = nil) -> EvenementFlux? {
        LectureEvenement.lire(TrameSSE(evenement: evenement, donnees: donnees))
    }

    func testFragment() {
        guard case .fragment(let texte)? = lire(#"{"type":"fragment","texte":"salut"}"#) else {
            return XCTFail("fragment attendu")
        }
        XCTAssertEqual(texte, "salut")
    }

    func testDebutPorteLidentiteDuMessageAVenir() {
        let charge = """
        {"type":"debut","conversation_id":"c1","message_id":"m2",\
        "modele_id":"qwen","parent_id":"m1","message_utilisateur_id":"m1"}
        """
        guard case .debut(let debut)? = lire(charge) else { return XCTFail("debut attendu") }
        XCTAssertEqual(debut.messageId, "m2")
        XCTAssertEqual(debut.messageUtilisateurId, "m1")
    }

    func testFinPorteLesMesures() {
        let charge = """
        {"type":"fin","message_id":"m2","tokens_generes":42,\
        "tokens_par_seconde":19.6,"duree_ms":2140,"interrompu":false}
        """
        guard case .fin(let fin)? = lire(charge) else { return XCTFail("fin attendue") }
        XCTAssertEqual(fin.tokensGeneres, 42)
        XCTAssertEqual(fin.dureeMs, 2140)
    }

    func testErreur() {
        let charge = #"{"type":"erreur","code":"x","message":"raté","remediation":"réessaie"}"#
        guard case .erreur(let erreur)? = lire(charge) else { return XCTFail("erreur attendue") }
        XCTAssertEqual(erreur.message, "raté")
    }

    func testSentinelleDONE() {
        XCTAssertEqual(lire("[DONE]"), .termine)
    }

    /// Un type inconnu ne doit pas tuer le flux : il est ignoré, la génération
    /// continue. Une app qui s'arrête sur un événement ajouté côté serveur est
    /// une app qui casse au prochain déploiement du PC.
    func testTypeInconnuIgnore() {
        XCTAssertNil(lire(#"{"type":"chose-neuve","x":1}"#))
    }

    func testChargeIllisibleIgnoree() {
        XCTAssertNil(lire("{pas du json"))
        XCTAssertNil(lire(""))
    }
}
