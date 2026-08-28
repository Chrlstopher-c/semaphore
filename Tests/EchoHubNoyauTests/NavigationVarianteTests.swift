import XCTest
@testable import EchoHubNoyau

/// Le « ‹ 2 / 3 › ». Ce sont trois lignes d'arithmétique, et c'est exactement
/// pour ça qu'elles se testent : un décalage d'un cran affiche une variante pour
/// une autre sans que rien ne casse visiblement.
final class NavigationVarianteTests: XCTestCase {

    private let arbre = ["b": ["a", "b", "c"], "seul": ["seul"]]

    func testLaPositionCompteAPartirDeUn() {
        let position = NavigationVariante.position(de: "b", dans: arbre)
        XCTAssertEqual(position?.rang, 2)
        XCTAssertEqual(position?.total, 3)
    }

    /// Un tour sans variante n'affiche rien : « 1 / 1 » occupe une rangée pour
    /// ne rien apprendre.
    func testUnSeulFrereNaPasDePosition() {
        XCTAssertNil(NavigationVariante.position(de: "seul", dans: arbre))
    }

    func testUnMessageAbsentDeLaTableNaPasDePosition() {
        XCTAssertNil(NavigationVariante.position(de: "inconnu", dans: arbre))
    }

    func testLeVoisinDeGaucheEtDeDroite() {
        XCTAssertEqual(NavigationVariante.voisin(de: "b", decalage: -1, dans: arbre), "a")
        XCTAssertEqual(NavigationVariante.voisin(de: "b", decalage: 1, dans: arbre), "c")
    }

    /// En bout de liste la flèche est DÉSACTIVÉE, pas masquée : un contrôle qui
    /// disparaît laisse croire à un bug.
    func testAucunVoisinAuDelaDesBords() {
        XCTAssertNil(NavigationVariante.voisin(de: "a", decalage: -1, dans: arbre))
        XCTAssertNil(NavigationVariante.voisin(de: "c", decalage: 1, dans: arbre))
    }

    func testUnDecalageNulRendLeMessageLuiMeme() {
        XCTAssertEqual(NavigationVariante.voisin(de: "b", decalage: 0, dans: arbre), "b")
    }

    /// Le contrat du serveur : la liste inclut le message lui-même. Une table
    /// qui l'oublierait ne doit pas produire un rang faux, mais rien.
    func testUneTableQuiNeContientPasLeMessageNeDevineRien() {
        let boiteuse = ["b": ["a", "c"]]
        XCTAssertNil(NavigationVariante.position(de: "b", dans: boiteuse))
        XCTAssertNil(NavigationVariante.voisin(de: "b", decalage: 1, dans: boiteuse))
    }
}
