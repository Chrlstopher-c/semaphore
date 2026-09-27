import XCTest
@testable import TamisNoyau

final class PistageTests: XCTestCase {
    func testLesPistesProposentSansToucherAuxGardesNiAuxFavoris() {
        let cliches = [
            Aides.cliche("cap1", Aides.date(2020), traits: [.capture], poids: 10),
            Aides.cliche("cap2", Aides.date(2021), traits: [.capture, .favori]),
            Aides.cliche("cap3", Aides.date(2019), traits: [.capture]),
            Aides.cliche("vid", Aides.date(2020), .video, poids: 300_000_000, duree: 60),
            Aides.cliche("furtive", Aides.date(2020), .video, poids: 1, duree: 1),
        ]
        let p = Pistage(cliches: cliches, qualites: [:], paires: [], gardes: ["cap3"])
        XCTAssertEqual(p.releve(.captures).proposes, ["cap1"])
        XCTAssertEqual(p.releve(.captures).poids, 10)
        XCTAssertEqual(p.releve(.videosLourdes).proposes, ["vid"])
        XCTAssertEqual(p.releve(.videosFurtives).proposes, ["furtive"])
    }

    func testLesRafalesGardentLaPhotoChoisie() {
        let cliches = [
            Aides.cliche("r1", Aides.date(2020), rafale: "R"),
            Aides.cliche("r2", Aides.date(2020), traits: [.choixRafale], rafale: "R"),
            Aides.cliche("r3", Aides.date(2020), rafale: "R"),
        ]
        let r = Pistage(cliches: cliches, qualites: [:], paires: [], gardes: []).releve(.rafales)
        XCTAssertEqual(r.groupes, [["r1", "r2", "r3"]])
        XCTAssertEqual(Set(r.proposes), ["r1", "r3"])
    }

    func testRateesEtUtilitaires() {
        let cliches = [Aides.cliche("flou", nil), Aides.cliche("recu", nil), Aides.cliche("belle", nil)]
        let q = [
            "flou": Qualite(score: -0.6, utilitaire: false),
            "recu": Qualite(score: -0.6, utilitaire: true),
            "belle": Qualite(score: 0.4, utilitaire: false),
        ]
        let p = Pistage(cliches: cliches, qualites: q, paires: [], gardes: [])
        XCTAssertEqual(p.releve(.ratees).proposes, ["flou"])
        XCTAssertEqual(p.releve(.utilitaires).proposes, ["recu"])
    }

    func testLesDecisionsSontExclusives() {
        var d = Decisions()
        d.mettreAuPanier(["a", "b"])
        d.garder(["b"])
        XCTAssertEqual(d.panier, ["a"])
        XCTAssertEqual(d.gardes, ["b"])
        d.restreindre(a: ["b"])
        XCTAssertTrue(d.panier.isEmpty)
    }

    func testLeCoffreRelitCeQuIlAEcrit() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var d = Decisions()
        d.mettreAuPanier(["x"])
        try Coffre.ecrire(d, "d.json", dans: dossier)
        XCTAssertEqual(try Coffre.lire(Decisions.self, "d.json", dans: dossier), d)
        XCTAssertNil(try Coffre.lire(Decisions.self, "absent.json", dans: dossier))
    }
}
