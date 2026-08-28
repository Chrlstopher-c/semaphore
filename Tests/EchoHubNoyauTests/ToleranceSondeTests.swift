import XCTest
@testable import EchoHubNoyau

/// Le bandeau « Machine injoignable » se levait au premier relevé raté, et une
/// requête ANNULÉE localement s'affichait « Relais injoignable — cancelled »
/// juste après une réponse réussie. Ces cas gardent les deux corrections sous
/// contrôle, sans réseau ni appareil.
final class ToleranceSondeTests: XCTestCase {

    // MARK: - Classement des erreurs

    func testUneAnnulationReseauDevientAnnuleEtPasInjoignable() {
        let url = URLError(.cancelled)
        XCTAssertTrue(ErreurRelais.vientDUneAnnulation(url))
        XCTAssertFalse(ErreurRelais.vientDUneAnnulation(URLError(.timedOut)))
        XCTAssertTrue(ErreurRelais.vientDUneAnnulation(CancellationError()))
    }

    func testAnnuleEstReconnueEtSansRemede() {
        XCTAssertTrue(ErreurRelais.annule.estAnnulation)
        XCTAssertFalse(ErreurRelais.injoignable("x").estAnnulation)
        // Une annulation n'a rien à faire réparer.
        XCTAssertNil(ErreurRelais.annule.remede)
    }

    func testInjoignableEtAnnuleSontTransitoiresMaisPasLeRefus() {
        XCTAssertTrue(ErreurRelais.injoignable("x").estTransitoire)
        XCTAssertTrue(ErreurRelais.annule.estTransitoire)
        XCTAssertFalse(ErreurRelais.refuse.estTransitoire)
        XCTAssertFalse(ErreurRelais.serveur(statut: 502, message: "", remede: nil).estTransitoire)
    }

    // MARK: - Hystérésis du bandeau

    func testUnPremierEchecTransitoireGardeLEtatConnu() {
        // Un à-coup isolé, avec un état déjà relevé : on garde, pas de bandeau.
        XCTAssertTrue(ToleranceSonde.garderDernierEtat(
            erreurEstTransitoire: true, aUnEtatConnu: true, echecsConsecutifs: 1))
    }

    func testDeuxEchecsDAffileeLeventLeBandeau() {
        XCTAssertFalse(ToleranceSonde.garderDernierEtat(
            erreurEstTransitoire: true, aUnEtatConnu: true, echecsConsecutifs: ToleranceSonde.seuil))
    }

    func testSansEtatConnuLePremierEchecSAffiche() {
        // Au démarrage, rien à préserver : montrer l'échec est légitime.
        XCTAssertFalse(ToleranceSonde.garderDernierEtat(
            erreurEstTransitoire: true, aUnEtatConnu: false, echecsConsecutifs: 1))
    }

    func testUnePanneDurableSAfficheDuPremierCoup() {
        // Jeton refusé, PC éteint : la relever ne changerait rien.
        XCTAssertFalse(ToleranceSonde.garderDernierEtat(
            erreurEstTransitoire: false, aUnEtatConnu: true, echecsConsecutifs: 1))
    }
}
