import XCTest
@testable import DuplexNoyau

/// L'en-tête de paquet est le point de contact le plus littéral entre les deux
/// implémentations : douze octets, deux boutismes différents, aucune marge.
/// Une erreur ici ne lève pas d'exception — elle produit du bruit.
final class EnTetePaquetTests: XCTestCase {

    private func charge(_ valeur: Int16 = 0) -> [Int16] {
        [Int16](repeating: valeur, count: EnTetePaquet.tramesParPaquet * EnTetePaquet.canaux)
    }

    // MARK: - Les constantes du protocole

    /// `☠` Ces chiffres sont écrits dans `PROTOCOLE.md`. Le test existe pour
    /// qu'un « petit ajustement » de l'un d'eux réveille quelqu'un.
    func testLesTaillesSontCellesDuProtocole() {
        XCTAssertEqual(EnTetePaquet.taille, 12)
        XCTAssertEqual(EnTetePaquet.tramesParPaquet, 240)
        XCTAssertEqual(EnTetePaquet.octetsCharge, 960)
        XCTAssertEqual(EnTetePaquet.taillePaquet, 972)
        XCTAssertEqual(EnTetePaquet.frequence, 48_000)
        XCTAssertEqual(EnTetePaquet.canaux, 2)
    }

    /// 240 trames à 48 kHz font exactement 5 ms.
    func testUnPaquetDureCinqMillisecondes() {
        let ms = Double(EnTetePaquet.tramesParPaquet) / EnTetePaquet.frequence * 1000
        XCTAssertEqual(ms, 5, accuracy: 0.0001)
    }

    // MARK: - Boutisme

    /// `☠` L'en-tête est en GROS-BOUTISTE. On vérifie octet par octet, pas par
    /// aller-retour : un encodeur et un décodeur tous les deux à l'envers se
    /// valident mutuellement et laissent passer la faute.
    func testLaSequenceEstEcriteEnGrosBoutiste() {
        let paquet = EnTetePaquet.composer(
            EnTetePaquet(sequence: 0x01020304, horodatage: 0x0A0B0C0D), charge: charge()
        )
        XCTAssertEqual([UInt8](paquet[4..<8]), [0x01, 0x02, 0x03, 0x04])
        XCTAssertEqual([UInt8](paquet[8..<12]), [0x0A, 0x0B, 0x0C, 0x0D])
    }

    /// `☠` La charge, elle, est en PETIT-BOUTISTE — dans le même paquet.
    func testLaChargeEstEcriteEnPetitBoutiste() {
        var echantillons = charge()
        echantillons[0] = 0x0102
        let paquet = EnTetePaquet.composer(
            EnTetePaquet(sequence: 1, horodatage: 0), charge: echantillons
        )
        XCTAssertEqual([UInt8](paquet[12..<14]), [0x02, 0x01])
    }

    func testLEnTeteSeRelitTelQuelEcrit() {
        let origine = EnTetePaquet(sequence: 4_294_967_290, horodatage: 123_456)
        let paquet = EnTetePaquet.composer(origine, charge: charge())
        guard case let .valide(relu) = EnTetePaquet.analyser(paquet) else {
            return XCTFail("paquet bien formé rejeté")
        }
        XCTAssertEqual(relu, origine)
        XCTAssertTrue(relu.pcmBrut)
    }

    func testLesEchantillonsNegatifsSurvivent() {
        var echantillons = charge()
        echantillons[0] = -32_768
        echantillons[1] = 32_767
        echantillons[2] = -1
        let paquet = EnTetePaquet.composer(
            EnTetePaquet(sequence: 1, horodatage: 0), charge: echantillons
        )
        let relus = EnTetePaquet.echantillons(paquet)
        XCTAssertEqual(relus.count, echantillons.count)
        XCTAssertEqual(Array(relus.prefix(3)), [-32_768, 32_767, -1])
    }

    // MARK: - Ce qu'on refuse, et pourquoi

    /// Le port UDP est ouvert : n'importe qui sur le réseau peut y écrire.
    func testUnDatagrammeSansMarqueurEstRejete() {
        var paquet = EnTetePaquet.composer(
            EnTetePaquet(sequence: 1, horodatage: 0), charge: charge()
        )
        paquet[0] = 0x58
        XCTAssertEqual(EnTetePaquet.analyser(paquet), .rejete(.marqueurInconnu))
    }

    func testUneVersionInconnueEstRejeteeAvecSonNumero() {
        var paquet = EnTetePaquet.composer(
            EnTetePaquet(sequence: 1, horodatage: 0), charge: charge()
        )
        paquet[2] = 9
        XCTAssertEqual(EnTetePaquet.analyser(paquet), .rejete(.versionInconnue(9)))
    }

    /// Le bit 0 des drapeaux réserve la place d'Opus. Cette version ne sait lire
    /// que du PCM brut : elle doit le DIRE, pas jouer du bruit.
    func testUnCodageNonSupporteEstRejete() {
        let paquet = EnTetePaquet.composer(
            EnTetePaquet(sequence: 1, horodatage: 0, drapeaux: 0x01), charge: charge()
        )
        XCTAssertEqual(EnTetePaquet.analyser(paquet), .rejete(.codageNonSupporte(drapeaux: 0x01)))
    }

    func testUnDatagrammeTropCourtEstRejete() {
        XCTAssertEqual(EnTetePaquet.analyser(Data([0x44, 0x58, 1, 0])), .rejete(.tropCourt(octets: 4)))
    }

    /// Un paquet tronqué en route : l'en-tête est bon, la charge non.
    func testUneChargeIncompleteEstRejetee() {
        let paquet = EnTetePaquet.composer(
            EnTetePaquet(sequence: 1, horodatage: 0), charge: charge()
        ).dropLast(4)
        XCTAssertEqual(
            EnTetePaquet.analyser(Data(paquet)), .rejete(.chargeIncomplete(octets: 956))
        )
    }
}
