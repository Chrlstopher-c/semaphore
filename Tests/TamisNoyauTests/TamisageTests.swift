import XCTest
@testable import TamisNoyau

final class TamisageTests: XCTestCase {
    func testLaBorneHauteEstExclue() {
        let plage = PlageDates.annee(2020, calendrier: Aides.calendrier)
        XCTAssertTrue(plage.contient(Aides.date(2020, 12, 31)))
        XCTAssertFalse(plage.contient(Aides.date(2021, 1, 1)))
        XCTAssertTrue(plage.contient(Aides.date(2020, 1, 1)))
    }

    func testUnClicheSansDateNEntreQueDansLaPlageIllimitee() {
        XCTAssertTrue(PlageDates.tout.contient(nil))
        XCTAssertFalse(PlageDates.annee(2020).contient(nil))
    }

    func testPlusDeTroisAns() {
        let plage = PlageDates.plusDe(annees: 3, maintenant: Aides.date(2026, 9, 27), calendrier: Aides.calendrier)
        XCTAssertTrue(plage.contient(Aides.date(2023, 9, 26)))
        XCTAssertFalse(plage.contient(Aides.date(2023, 9, 28)))
    }

    func testLesFavorisSontEpargnesParDefaut() {
        let fav = Aides.cliche("f", Aides.date(2019), traits: [.favori])
        XCTAssertFalse(Tamisage().retient(fav))
        XCTAssertTrue(Tamisage(epargnerFavoris: false).retient(fav))
    }

    func testUnPoidsInconnuNePassePasLePlancher() {
        let t = Tamisage(poidsMin: 10)
        XCTAssertFalse(t.retient(Aides.cliche("a", nil, poids: nil)))
        XCTAssertTrue(t.retient(Aides.cliche("b", nil, poids: 10)))
    }

    func testTraitsEtMedias() {
        let t = Tamisage(medias: [.photo], traits: [.capture])
        XCTAssertTrue(t.retient(Aides.cliche("a", nil, traits: [.capture])))
        XCTAssertFalse(t.retient(Aides.cliche("b", nil)))
        XCTAssertFalse(t.retient(Aides.cliche("c", nil, .video, traits: [.capture])))
    }

    func testPasserTrieChronologiquementSansDateALaFin() {
        let r = Tamisage().passer([
            Aides.cliche("x", nil), Aides.cliche("b", Aides.date(2021)), Aides.cliche("a", Aides.date(2019)),
        ])
        XCTAssertEqual(r.map(\.id), ["a", "b", "x"])
    }

    func testOctetsEnDecimal() {
        XCTAssertEqual(Octets.lisible(12_400_000_000), "12,4 Go")
        XCTAssertEqual(Octets.lisible(512), "512 o")
        XCTAssertEqual(Octets.lisible(150_000_000), "150 Mo")
    }
}
