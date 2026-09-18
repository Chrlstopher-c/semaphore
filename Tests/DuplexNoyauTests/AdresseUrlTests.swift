import XCTest
@testable import DuplexNoyau

/// L'adresse que Bonjour rend n'est pas une URL. Ces essais fixent la
/// traduction — c'est elle qui rendait le PC injoignable alors qu'il répondait.
final class AdresseUrlTests: XCTestCase {

    func testUneAdresseIPv4PerdSaZone() {
        XCTAssertEqual(AdresseUrl.hotePourUrl("192.168.1.10%en0"), "192.168.1.10")
    }

    func testUneAdresseIPv4SansZoneNeChangePas() {
        XCTAssertEqual(AdresseUrl.hotePourUrl("192.168.1.10"), "192.168.1.10")
    }

    func testUneAdresseIPv6GardeSaZoneEchappee() {
        XCTAssertEqual(AdresseUrl.hotePourUrl("fe80::1%en0"), "[fe80::1%25en0]")
    }

    func testUneAdresseIPv6DejaEntreCrochetsNEstPasDoublee() {
        XCTAssertEqual(AdresseUrl.hotePourUrl("[fe80::1%en0]"), "[fe80::1%25en0]")
    }

    func testLUrlDuCanalEstFormeePourUneIPv4Zonee() {
        let url = AdresseUrl.canal(hote: "192.168.1.10%en0", port: 7651)
        XCTAssertEqual(url?.absoluteString, "ws://192.168.1.10:7651")
        XCTAssertEqual(url?.host, "192.168.1.10")
        XCTAssertEqual(url?.port, 7651)
    }

    func testLUrlDuCanalEstFormeePourUneIPv6Zonee() {
        let url = AdresseUrl.canal(hote: "fe80::1%en0", port: 7651)
        XCTAssertEqual(url?.absoluteString, "ws://[fe80::1%25en0]:7651")
        XCTAssertEqual(url?.port, 7651)
    }
}
