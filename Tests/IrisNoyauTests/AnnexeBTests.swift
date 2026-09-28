import Foundation
import XCTest
@testable import IrisNoyau

/// La conversion AVCC → Annex-B est ce que le décodeur du PC lit : une erreur
/// d'un octet donne une image verte, sans aucun message d'erreur.
final class AnnexeBTests: XCTestCase {

    func testDeuxNALsRecoiventChacuneLeurPrefixe() {
        let avcc = Data([0, 0, 0, 2, 0x65, 0xAA, 0, 0, 0, 1, 0x41])
        XCTAssertEqual(AnnexeB.depuisAVCC(avcc), Data([0, 0, 0, 1, 0x65, 0xAA, 0, 0, 0, 1, 0x41]))
    }

    func testUneLongueurQuiDebordeRendNil() {
        XCTAssertNil(AnnexeB.depuisAVCC(Data([0, 0, 0, 9, 0x65])))
    }

    func testUnEnTeteTronqueRendNil() {
        XCTAssertNil(AnnexeB.depuisAVCC(Data([0, 0, 0, 1, 0x41, 0, 0])))
    }

    func testLesJeuxDeParametresPassentEnTete() {
        let unite = AnnexeB.uniteAcces(parametres: [Data([0x67, 1]), Data([0x68, 2])], avcc: Data([0, 0, 0, 1, 0x65]))
        XCTAssertEqual(unite, Data([0, 0, 0, 1, 0x67, 1, 0, 0, 0, 1, 0x68, 2, 0, 0, 0, 1, 0x65]))
    }

    func testLaTrameEstPrefixeeDeSaLongueurGrosBoutiste() {
        let unite = Data(repeating: 7, count: 258)
        let trame = AnnexeB.encadrer(unite)
        XCTAssertEqual([UInt8](trame.prefix(4)), [0, 0, 1, 2])
        XCTAssertEqual(trame.count, 262)
    }
}
