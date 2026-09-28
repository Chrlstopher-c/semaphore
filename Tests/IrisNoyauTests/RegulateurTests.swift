import XCTest
@testable import IrisNoyau

/// La régulation ne doit jamais laisser passer une image P après un saut : le PC
/// afficherait de la bouillie jusqu'à la clé suivante.
final class RegulateurTests: XCTestCase {

    func testRienNePasseAvantLaPremiereImageCle() {
        var r = Regulateur(plafond: 100)
        XCTAssertFalse(r.decider(taille: 10, cle: false))
        XCTAssertTrue(r.decider(taille: 10, cle: true))
        XCTAssertTrue(r.decider(taille: 10, cle: false))
    }

    func testUnSautObligeAAttendreLaCleSuivante() {
        var r = Regulateur(plafond: 100)
        XCTAssertTrue(r.decider(taille: 60, cle: true))
        XCTAssertFalse(r.decider(taille: 60, cle: false))
        r.acquitter(60)
        XCTAssertFalse(r.decider(taille: 10, cle: false), "après un saut, seule une clé repart")
        XCTAssertTrue(r.decider(taille: 10, cle: true))
    }

    func testUneLiaisonMorteRefuseMemeLesCles() {
        var r = Regulateur(plafond: 100)
        XCTAssertTrue(r.decider(taille: 90, cle: true))
        XCTAssertTrue(r.decider(taille: 10, cle: false))
        XCTAssertTrue(r.decider(taille: 150, cle: true))
        XCTAssertFalse(r.decider(taille: 10, cle: true))
    }

    func testLAcquittementNeDescendJamaisSousZero() {
        var r = Regulateur(plafond: 100)
        r.acquitter(50)
        XCTAssertEqual(r.enVol, 0)
    }
}
