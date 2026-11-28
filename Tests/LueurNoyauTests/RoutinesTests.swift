import Foundation
import XCTest
@testable import LueurNoyau

/// Routines : ce qui, faux, ferait afficher une autre heure, d'autres jours, ou enverrait au Pi des instructions
/// qu'il refuse — et le geste appliqué tout de suite (plus de retour en arrière de l'écran).
final class RoutinesTests: XCTestCase {
    private let pi = """
    {"id": "reveil", "name": "Réveil vert", "duration": 390.0, "steps": [
      {"kind": "off", "duration": 0.0, "ease": "inout"},
      {"kind": "fade", "color": "#00ff00", "brightness": 100, "duration": 60.0, "ease": "inout"},
      {"kind": "pulse", "color": "#00ff00", "duration": 300.0, "ease": "inout", "low": 25, "high": 100, "period": 4.0},
      {"kind": "effect", "code": 147, "duration": 30.0, "ease": "inout"}]}
    """

    func testScenarioDuPiSeLitEtSeRenvoiePropre() throws {
        let sc = try JSONDecoder().decode(Scenario.self, from: Data(pi.utf8))
        XCTAssertEqual(sc.etapes.map(\.genre), [.extinction, .fondu, .pulsation, .animation])
        XCTAssertEqual(sc.etapes[2].creux, 25)
        let corps = try XCTUnwrap(JSONSerialization.jsonObject(with: sc.corps) as? [String: Any])
        let etapes = try XCTUnwrap(corps["steps"] as? [[String: Any]])
        XCTAssertNil(etapes[0]["ease"], "une extinction n'a pas de courbe")
        XCTAssertEqual(etapes[1]["ease"] as? String, "inout")
        XCTAssertEqual(etapes[3]["code"] as? Int, 147)
        XCTAssertEqual(corps["name"] as? String, "Réveil vert")
    }

    func testRoutineCorpsSansIdNiProchain() throws {
        let r = Routine(id: "reveil", nom: "Réveil", heure: "07:00", scenario: "reveil", jours: [1, 2], active: false,
                        prochain: "2026-11-29T07:00")
        let corps = try XCTUnwrap(JSONSerialization.jsonObject(with: r.corps) as? [String: Any])
        XCTAssertEqual(Set(corps.keys), ["name", "time", "scenario", "days", "enabled"])
        XCTAssertEqual(corps["enabled"] as? Bool, false)
    }

    func testDurees() {
        XCTAssertEqual(Horaire.duree(4.8), "4,8 s")
        XCTAssertEqual(Horaire.duree(45), "45 s")
        XCTAssertEqual(Horaire.duree(390), "6 min 30 s")
        XCTAssertEqual(Horaire.duree(1820), "30 min 20 s")
        XCTAssertEqual(Horaire.duree(3900), "1 h 05")
    }

    func testJours() {
        XCTAssertEqual(Horaire.jours([7, 1, 2, 3, 4, 5, 6]), "Tous les jours")
        XCTAssertEqual(Horaire.jours([1, 2, 3, 4, 5]), "En semaine")
        XCTAssertEqual(Horaire.jours([6, 7]), "Le week-end")
        XCTAssertEqual(Horaire.jours([1, 3]), "lun. mer.")
    }

    func testProchainPassage() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        let samedi = cal.date(from: DateComponents(year: 2026, month: 11, day: 28, hour: 7, minute: 30))!
        XCTAssertEqual(Horaire.prochain("2026-11-28T21:00", maintenant: samedi, calendrier: cal), "Ce soir 21:00")
        XCTAssertEqual(Horaire.prochain("2026-11-28T12:00", maintenant: samedi, calendrier: cal), "Aujourd'hui 12:00")
        XCTAssertEqual(Horaire.prochain("2026-11-29T07:00", maintenant: samedi, calendrier: cal), "Demain 07:00")
        XCTAssertEqual(Horaire.prochain("2026-11-30T14:00", maintenant: samedi, calendrier: cal), "Lundi 14:00")
        XCTAssertEqual(Horaire.jourIso(samedi, calendrier: cal), 6)
    }

    func testIdentifiants() {
        XCTAssertEqual(Horaire.identifiant("Réveil doux !", pris: []), "reveil-doux")
        XCTAssertEqual(Horaire.identifiant("Réveil", pris: ["reveil", "reveil-2"]), "reveil-3")
        XCTAssertEqual(Horaire.identifiant("…", pris: []), "routine")
    }

    func testRenduSuitLaLumiere() {
        let etapes = [Etape.neuve(.fondu), Etape.neuve(.animation), Etape.neuve(.maintien), Etape.neuve(.extinction)]
        let r = Horaire.rendu(etapes)
        XCTAssertEqual(r[0].debut, Horaire.eteint)
        XCTAssertEqual(r[1].fin, r[0].fin, "une animation garde la dernière couleur fixe")
        XCTAssertTrue(r[2].animee, "un maintien après une animation la prolonge")
        XCTAssertEqual(r[3].fin, Horaire.eteint)
        XCTAssertFalse(r[3].animee)
    }

    func testGesteAppliqueToutDeSuite() {
        var e = EtatLumiere(allume: false, couleur: "#ff0000", intensite: 30, effet: 147, vitesse: 50, favoris: [],
                            relie: true)
        e.appliquer(.couleur(Nuance(hexa: "#00ff00")!))
        XCTAssertEqual(e.couleur, "#00ff00")
        XCTAssertTrue(e.allume)
        XCTAssertNil(e.effet, "une couleur fixe arrête l'animation")
        e.appliquer(.intensite(80))
        XCTAssertEqual(e.intensite, 80)
        e.appliquer(.allumer(false))
        XCTAssertFalse(e.allume)
    }
}
