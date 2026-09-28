import Foundation
import XCTest
@testable import IrisNoyau

/// Le contrat du relais Iris (`relais/salon.ts`), lu côté iPhone.
final class MessageRelaisTests: XCTestCase {

    func testLaListeDesRecepteursSeLit() {
        let json = #"{"type":"recepteurs","liste":[{"nom":"tour","veut":true,"session":3,"adresses":["192.168.1.10:8798"]}]}"#
        XCTAssertEqual(
            MessageRelais.lire(Data(json.utf8)),
            .recepteurs([Recepteur(nom: "tour", veut: true, session: 3, adresses: ["192.168.1.10:8798"])])
        )
    }

    func testUnRecepteurSansAdresseResteLisible() {
        let json = #"{"type":"recepteurs","liste":[{"nom":"portable","veut":false,"session":1}]}"#
        XCTAssertEqual(
            MessageRelais.lire(Data(json.utf8)),
            .recepteurs([Recepteur(nom: "portable", veut: false, session: 1, adresses: [])])
        )
    }

    func testLEtatDUnPosteSeLit() {
        let json = #"{"type":"etat","de":"tour","etat":"En direct · 1280×720 · 30 i/s"}"#
        XCTAssertEqual(MessageRelais.lire(Data(json.utf8)), .etat(de: "tour", texte: "En direct · 1280×720 · 30 i/s"))
    }

    func testUnMessageWebRTCEstIgnore() {
        XCTAssertEqual(MessageRelais.lire(Data(#"{"type":"reponse","de":"tour","sdp":"v=0"}"#.utf8)), .ignore)
        XCTAssertEqual(MessageRelais.lire(Data("pas du json".utf8)), .ignore)
    }

    func testLaPoigneeDeMainEstUneLigneJSON() throws {
        let ligne = MessageSortant.poigneeDeMain(cle: "abc")
        XCTAssertEqual(ligne.last, 0x0A)
        let objet = try JSONSerialization.jsonObject(with: ligne.dropLast()) as? [String: String]
        XCTAssertEqual(objet?["cle"], "abc")
    }

    func testLesAdressesSeLisentEtSeFiltrent() {
        XCTAssertEqual(AdressePoste("192.168.1.10:8798"), AdressePoste("192.168.1.10:8798"))
        XCTAssertEqual(AdressePoste("192.168.1.10:8798")?.port, 8798)
        XCTAssertNil(AdressePoste("192.168.1:8798"))
        XCTAssertNil(AdressePoste("192.168.1.300:8798"))
        XCTAssertNil(AdressePoste("192.168.1.10"))
    }
}
