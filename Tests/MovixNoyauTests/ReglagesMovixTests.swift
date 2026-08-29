import XCTest
@testable import MovixNoyau

final class ReglagesMovixTests: XCTestCase {

    func testDefautValideEtPorteLInstanceLAN() {
        let r = ReglagesMovix.parDefaut
        XCTAssertTrue(r.adresseValide)
        XCTAssertEqual(r.url?.host, "10.0.0.3")
        XCTAssertEqual(r.url?.port, 3000)
        XCTAssertEqual(r.url?.scheme, "http")
    }

    func testSchemaComblePourUneIpNue() {
        let r = ReglagesMovix(adresse: "10.0.0.4:3000")
        XCTAssertEqual(r.url?.scheme, "http")
        XCTAssertEqual(r.url?.host, "10.0.0.4")
        XCTAssertEqual(r.url?.port, 3000)
    }

    func testSchemaExpliciteRespecte() {
        let r = ReglagesMovix(adresse: "https://movix.tax")
        XCTAssertEqual(r.url?.scheme, "https")
        XCTAssertEqual(r.url?.host, "movix.tax")
    }

    func testEspacesIgnores() {
        let r = ReglagesMovix(adresse: "  10.0.0.3:3000  ")
        XCTAssertTrue(r.adresseValide)
        XCTAssertEqual(r.url?.host, "10.0.0.3")
    }

    func testAdresseVideInvalide() {
        XCTAssertFalse(ReglagesMovix(adresse: "").adresseValide)
        XCTAssertFalse(ReglagesMovix(adresse: "   ").adresseValide)
        XCTAssertNil(ReglagesMovix(adresse: "").url)
    }
}
