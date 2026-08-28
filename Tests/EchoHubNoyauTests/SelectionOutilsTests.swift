import XCTest
@testable import EchoHubNoyau

/// `nil` = tous, `[]` = aucun. Les confondre priverait d'outils une conversation
/// qui n'a jamais choisi, ou en rendrait à celle qui les a tous coupés — et rien
/// à l'écran ne le dirait : le modèle répondrait juste « autrement ».
final class SelectionOutilsTests: XCTestCase {

    private let catalogue = ["recherche_web", "lire_fichier", "executer"]

    // MARK: - Les trois états

    func testNilVeutDireTous() {
        let selection = SelectionOutils(outilsActifs: nil)
        XCTAssertTrue(selection.contient("recherche_web"))
        XCTAssertTrue(selection.contient("un_outil_ajoute_demain"))
    }

    func testListeVideVeutDireAucun() {
        XCTAssertFalse(SelectionOutils(outilsActifs: []).contient("recherche_web"))
    }

    func testUneListeNeContientQueLesSiens() {
        let selection = SelectionOutils(outilsActifs: ["lire_fichier"])
        XCTAssertTrue(selection.contient("lire_fichier"))
        XCTAssertFalse(selection.contient("executer"))
    }

    // MARK: - La bascule

    func testCouperUnOutilDepuisTousDonneLaListeDesAutres() {
        let apres = SelectionOutils().basculant("executer", parmi: catalogue)
        XCTAssertEqual(apres.outilsActifs, ["recherche_web", "lire_fichier"])
    }

    /// Tout recocher rend `nil`, pas la liste complète : la différence est entre
    /// « je veux tous les outils », y compris ceux que le PC enregistrera
    /// demain, et « je veux exactement ces trois-là ».
    func testToutRecocherRedonneTous() {
        let ampute = SelectionOutils(outilsActifs: ["recherche_web", "lire_fichier"])
        XCTAssertNil(ampute.basculant("executer", parmi: catalogue).outilsActifs)
    }

    func testCouperLeDernierDonneAucunPasTous() {
        let dernier = SelectionOutils(outilsActifs: ["executer"])
        XCTAssertEqual(dernier.basculant("executer", parmi: catalogue).outilsActifs, [])
    }

    // MARK: - Le fil

    /// `encodeIfPresent` — ce que Swift synthétise — OMETTRAIT la clé pour un
    /// `nil`. Le serveur le lit aujourd'hui comme « tous », mais par accident.
    func testUnNilSEcritNullEtPasUneCleAbsente() throws {
        let donnees = try CodageJSON.encodeur().encode(SelectionOutils(outilsActifs: nil))
        XCTAssertEqual(String(decoding: donnees, as: UTF8.self), "{\"outils_actifs\":null}")
    }

    func testUneListeSEcritEnSnakeCase() throws {
        let donnees = try CodageJSON.encodeur().encode(SelectionOutils(outilsActifs: ["a"]))
        XCTAssertEqual(String(decoding: donnees, as: UTF8.self), "{\"outils_actifs\":[\"a\"]}")
    }

    func testDecodageDeLaFormeExacteDuServeur() throws {
        let decodeur = CodageJSON.decodeur()
        let tous = try decodeur.decode(
            SelectionOutils.self, from: Data("{\"outils_actifs\":null}".utf8)
        )
        XCTAssertNil(tous.outilsActifs)
        let aucun = try decodeur.decode(
            SelectionOutils.self, from: Data("{\"outils_actifs\":[]}".utf8)
        )
        XCTAssertEqual(aucun.outilsActifs, [])
    }

    /// Le coût d'une déclaration est `null` quand aucun modèle n'est chargé.
    /// Un zéro se lirait « cet outil ne coûte rien ».
    func testUnCoutNonMesurableResteUneAbsence() throws {
        let json = """
        {"nom":"recherche_web","description":"cherche","groupe":"web","tokens_definition":null}
        """
        let outil = try CodageJSON.decodeur().decode(
            OutilDisponible.self, from: Data(json.utf8)
        )
        XCTAssertNil(outil.tokensDefinition)
        XCTAssertEqual(outil.groupe, "web")
    }
}
