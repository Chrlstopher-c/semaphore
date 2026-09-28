import Foundation
import XCTest
@testable import LueurNoyau

/// La roue, le format hexadécimal et la file d'envoi : ce qui, faux, enverrait au ruban une autre couleur que
/// celle sous le doigt — sans aucune erreur visible.
final class LueurNoyauTests: XCTestCase {

    func testHexaAllerRetour() {
        XCTAssertEqual(Nuance(hexa: "#FF00ff")?.hexa, "#ff00ff")
        XCTAssertEqual(Nuance(hexa: "00e5ff"), Nuance(rouge: 0, vert: 0xE5, bleu: 0xFF))
        XCTAssertNil(Nuance(hexa: "#ff00f"))
        XCTAssertNil(Nuance(hexa: "#gg0000"))
    }

    func testTeintesPrimaires() {
        XCTAssertEqual(Nuance(teinte: 0, saturation: 1).hexa, "#ff0000")
        XCTAssertEqual(Nuance(teinte: 120, saturation: 1).hexa, "#00ff00")
        XCTAssertEqual(Nuance(teinte: 240, saturation: 1).hexa, "#0000ff")
        XCTAssertEqual(Nuance(teinte: -60, saturation: 1).hexa, "#ff00ff")
        XCTAssertEqual(Nuance(teinte: 77, saturation: 0).hexa, "#ffffff")
    }

    func testPlaceSurRoueInverseLaRoue() {
        for teinte in stride(from: 0.0, to: 360, by: 30) {
            let place = Nuance(teinte: teinte, saturation: 0.8).placeSurRoue
            XCTAssertEqual(place.teinte, teinte, accuracy: 1)
            XCTAssertEqual(place.saturation, 0.8, accuracy: 0.01)
        }
    }

    func testRoueSensHoraireRepereEcran() {
        XCTAssertEqual(Roue.nuance(dx: 100, dy: 0, rayon: 100).hexa, "#ff0000")
        // y vers le bas : un quart de tour horaire depuis la droite = 90°, entre jaune et vert.
        XCTAssertEqual(Roue.nuance(dx: 0, dy: 100, rayon: 100).hexa, "#80ff00")
        XCTAssertEqual(Roue.nuance(dx: 0, dy: 0, rayon: 100).hexa, "#ffffff")
        XCTAssertEqual(Roue.nuance(dx: 500, dy: 0, rayon: 100).hexa, "#ff0000")
    }

    func testPositionEtNuanceSeRepondent() {
        let depart = Nuance(teinte: 200, saturation: 0.6)
        let point = Roue.position(de: depart, rayon: 140)
        XCTAssertEqual(Roue.nuance(dx: point.dx, dy: point.dy, rayon: 140), depart)
    }

    func testCorpsJSON() throws {
        let allumer = try JSONSerialization.jsonObject(with: Commande.allumer(true).corps) as? [String: Bool]
        XCTAssertEqual(allumer, ["on": true])
        XCTAssertEqual(String(decoding: Commande.couleur(Nuance(rouge: 255, vert: 0, bleu: 16)).corps, as: UTF8.self),
                       ##"{"color":"#ff0010"}"##)
        XCTAssertEqual(String(decoding: Commande.effet(0x87).corps, as: UTF8.self), #"{"code":135}"#)
        XCTAssertEqual(String(decoding: Commande.effet(nil).corps, as: UTF8.self), #"{"code":null}"#)
    }

    func testFileGardeLaDerniereParFamilleDansLOrdre() {
        var file = FileCommandes()
        file.deposer(.couleur(Nuance(teinte: 0, saturation: 1)))
        file.deposer(.allumer(true))
        file.deposer(.couleur(Nuance(teinte: 240, saturation: 1)))
        XCTAssertEqual(file.prendre(), .couleur(Nuance(teinte: 240, saturation: 1)))
        XCTAssertEqual(file.prendre(), .allumer(true))
        XCTAssertNil(file.prendre())
        XCTAssertTrue(file.estVide)
    }

    func testDecodeEtatDuServeur() throws {
        let json = #"""
        {"sent": true, "state": {"power": true, "color": "#00e5ff", "brightness": 100, "effect": null,
         "last_effect": 147, "speed": 50, "favorites": ["#ff00ff"], "connected": true}}
        """#
        let reponse = try JSONDecoder().decode(ReponseAction.self, from: Data(json.utf8))
        XCTAssertTrue(reponse.envoye)
        XCTAssertEqual(reponse.etat.couleur, "#00e5ff")
        XCTAssertNil(reponse.etat.effet)
        XCTAssertEqual(reponse.etat.dernierEffet, 147)
        XCTAssertEqual(reponse.etat.favoris, ["#ff00ff"])
    }
}
