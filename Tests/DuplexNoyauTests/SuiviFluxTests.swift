import XCTest
@testable import DuplexNoyau

/// UDP perd, double et désordonne. Ce suivi décide de ce qu'on fait de chaque
/// cas — et il le décide en trames, parce que c'est en trames que le trou se
/// comble en silence.
final class SuiviFluxTests: XCTestCase {

    func testLePremierPaquetNAPasDeReference() {
        var suivi = SuiviFlux()
        XCTAssertEqual(suivi.accueillir(sequence: 4_000), .premier)
        XCTAssertEqual(suivi.derniereSequence, 4_000)
        XCTAssertEqual(suivi.paquetsRecus, 1)
    }

    func testLaSuiteAttendueEstContinue() {
        var suivi = SuiviFlux()
        _ = suivi.accueillir(sequence: 10)
        XCTAssertEqual(suivi.accueillir(sequence: 11), .continu)
        XCTAssertEqual(suivi.accueillir(sequence: 12), .continu)
        XCTAssertEqual(suivi.paquetsPerdus, 0)
        XCTAssertEqual(suivi.trous, 0)
    }

    /// `☠` Le trou se rend en TRAMES, exactement la durée manquante : trois
    /// paquets perdus valent 720 trames, soit 15 ms de silence à insérer.
    func testUnTrouRendLaDureeManquanteExacte() {
        var suivi = SuiviFlux()
        _ = suivi.accueillir(sequence: 100)
        XCTAssertEqual(suivi.accueillir(sequence: 104), .trou(tramesManquantes: 720))
        XCTAssertEqual(suivi.paquetsPerdus, 3)
        XCTAssertEqual(suivi.trous, 1)
        XCTAssertEqual(suivi.tramesPerdues, 720)
    }

    /// Au-delà du plafond on ne comble plus : combler cinq minutes de coupure
    /// remplirait le tampon de silence et la latence ne redescendrait jamais.
    func testUnSautTropGrandEstUneRuptureEtPasUnTrou() {
        var suivi = SuiviFlux()
        _ = suivi.accueillir(sequence: 1)
        let saut = UInt32(SuiviFlux.plafondTrouPaquets + 50)
        XCTAssertEqual(
            suivi.accueillir(sequence: 1 + saut + 1),
            .rupture(paquetsManquants: SuiviFlux.plafondTrouPaquets + 50)
        )
        XCTAssertEqual(suivi.ruptures, 1)
        XCTAssertEqual(suivi.trous, 0)
    }

    /// Juste sous le plafond, c'est encore un trou comblable — la frontière
    /// compte, un test qui ne l'éprouve pas ne prouve rien.
    func testLaFrontiereDuPlafondSeTientDuBonCote() {
        var suivi = SuiviFlux()
        _ = suivi.accueillir(sequence: 1)
        let manquants = SuiviFlux.plafondTrouPaquets
        guard case let .trou(trames) = suivi.accueillir(sequence: UInt32(1 + manquants + 1)) else {
            return XCTFail("au plafond exact, ça reste un trou")
        }
        XCTAssertEqual(trames, manquants * EnTetePaquet.tramesParPaquet)
    }

    func testUnDoublonEstJete() {
        var suivi = SuiviFlux()
        _ = suivi.accueillir(sequence: 50)
        _ = suivi.accueillir(sequence: 51)
        XCTAssertEqual(suivi.accueillir(sequence: 51), .doublonOuRetard)
        XCTAssertEqual(suivi.derniereSequence, 51, "un doublon ne fait pas reculer la référence")
        XCTAssertEqual(suivi.doublons, 1)
    }

    /// UDP ne garantit pas l'ordre : un paquet arrivé après son suivant est en
    /// retard, pas en avance de quatre milliards.
    func testUnPaquetEnRetardEstJeteEtPasPrisPourUnSautGeant() {
        var suivi = SuiviFlux()
        _ = suivi.accueillir(sequence: 500)
        XCTAssertEqual(suivi.accueillir(sequence: 495), .doublonOuRetard)
        XCTAssertEqual(suivi.paquetsPerdus, 0)
    }

    /// `☠` Le rebouclage du `UInt32` arrive après ~248 jours d'écoute continue.
    /// Une comparaison ordinaire y verrait un saut de quatre milliards et
    /// couperait le son ; la soustraction cyclique voit une suite normale.
    func testLeRebouclageDeLaSequenceNeCassePasLeFlux() {
        var suivi = SuiviFlux()
        _ = suivi.accueillir(sequence: UInt32.max - 1)
        XCTAssertEqual(suivi.accueillir(sequence: UInt32.max), .continu)
        XCTAssertEqual(suivi.accueillir(sequence: 0), .continu)
        XCTAssertEqual(suivi.accueillir(sequence: 1), .continu)
        XCTAssertEqual(suivi.paquetsPerdus, 0)
    }

    /// Un trou qui enjambe le rebouclage reste un trou de la bonne taille.
    func testUnTrouAuMomentDuRebouclageGardeLaBonneTaille() {
        var suivi = SuiviFlux()
        _ = suivi.accueillir(sequence: UInt32.max - 1)
        XCTAssertEqual(
            suivi.accueillir(sequence: 2),
            .trou(tramesManquantes: 3 * EnTetePaquet.tramesParPaquet)
        )
    }

    func testReprendreFaitRepartirEnPremier() {
        var suivi = SuiviFlux()
        _ = suivi.accueillir(sequence: 9_000)
        suivi.reprendre()
        XCTAssertEqual(suivi.accueillir(sequence: 12), .premier)
        XCTAssertEqual(suivi.paquetsPerdus, 0, "reprendre n'invente pas de perte")
    }
}
