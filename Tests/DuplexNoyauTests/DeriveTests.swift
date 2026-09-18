import XCTest
@testable import DuplexNoyau

/// Le rattrapage de dérive est la pièce qui décide si une écoute tient une heure.
/// Elle est difficile à constater à l'oreille — l'écart se compte en dizaines de
/// parties par million — donc c'est ici qu'elle se prouve, ou nulle part.
final class DeriveTests: XCTestCase {

    // MARK: - La consigne

    func testALaCibleOnNeCorrigePas() {
        XCTAssertEqual(CorrectionDerive.facteurVise(remplissageMs: 100), 1)
    }

    /// Sans zone morte, le correcteur pourchasse le bruit de mesure et module le
    /// débit en permanence pour rien.
    func testLaZoneMorteLaisseLePetitEcartTranquille() {
        XCTAssertEqual(CorrectionDerive.facteurVise(remplissageMs: 103), 1)
        XCTAssertEqual(CorrectionDerive.facteurVise(remplissageMs: 97), 1)
        XCTAssertNotEqual(CorrectionDerive.facteurVise(remplissageMs: 110), 1)
    }

    /// `☠` Le signe. Tampon TROP PLEIN → on lit plus vite pour le vider. Inversé,
    /// le correcteur creuse l'écart au lieu de le combler, et l'erreur ne se voit
    /// qu'après vingt minutes d'écoute.
    func testTropPleinOnAccelereTropVideOnRalentit() {
        XCTAssertGreaterThan(CorrectionDerive.facteurVise(remplissageMs: 140), 1)
        XCTAssertLessThan(CorrectionDerive.facteurVise(remplissageMs: 60), 1)
    }

    /// Le plafond du protocole : ±0,3 %, jamais plus, quel que soit l'écart.
    func testLaCorrectionNeDepasseJamaisTroisMillemes() {
        for remplissage in stride(from: 0.0, through: 600.0, by: 1.0) {
            let facteur = CorrectionDerive.facteurVise(remplissageMs: remplissage)
            XCTAssertLessThanOrEqual(facteur, 1 + CorrectionDerive.ecartMaximal)
            XCTAssertGreaterThanOrEqual(facteur, 1 - CorrectionDerive.ecartMaximal)
        }
        XCTAssertEqual(
            CorrectionDerive.facteurVise(remplissageMs: 100_000),
            1 + CorrectionDerive.ecartMaximal, accuracy: 1e-12
        )
    }

    // MARK: - Le lissage

    /// `☠` Un facteur qui saute d'un bloc à l'autre produit un craquement à
    /// chaque marche. Le premier pas doit être minuscule.
    func testLePremierPasEstMinuscule() {
        var correction = CorrectionDerive()
        let facteur = correction.observer(remplissageMs: 300)
        XCTAssertGreaterThan(facteur, 1)
        XCTAssertLessThan(facteur - 1, CorrectionDerive.ecartMaximal / 10)
    }

    func testLeFacteurRejointSaConsigneEtSyTient() {
        var correction = CorrectionDerive()
        for _ in 0..<2_000 { correction.observer(remplissageMs: 300) }
        XCTAssertEqual(correction.facteur, 1 + CorrectionDerive.ecartMaximal, accuracy: 1e-6)
    }

    func testReinitialiserRamèneAuNominal() {
        var correction = CorrectionDerive()
        for _ in 0..<500 { correction.observer(remplissageMs: 20) }
        XCTAssertLessThan(correction.facteur, 1)
        correction.reinitialiser()
        XCTAssertEqual(correction.facteur, 1)
    }

    // MARK: - La lecture étirée

    func testAFacteurUnOnConsommeExactementCeQuOnProduit() {
        var lecteur = LectureEtiree()
        let source = [Int16](repeating: 1_000, count: 4_096)
        var sortie = [Int16](repeating: 0, count: 512 * 2)
        let consommees = lecteur.produire(
            trames: 512, facteur: 1,
            source: { (source[$0 * 2], source[$0 * 2 + 1]) },
            sortie: { sortie[$0 * 2] = $1; sortie[$0 * 2 + 1] = $2 }
        )
        XCTAssertEqual(consommees, 512)
        XCTAssertEqual(lecteur.phase, 0, accuracy: 1e-9)
        XCTAssertTrue(sortie.allSatisfy { $0 == 1_000 })
    }

    /// Un facteur > 1 consomme plus de source que de sortie : c'est exactement
    /// comme ça que le tampon trop plein se vide.
    func testUnFacteurPlusGrandConsommePlusDeSource() {
        var lecteur = LectureEtiree()
        var consommees = 0
        for _ in 0..<100 {
            consommees += lecteur.produire(
                trames: 512, facteur: 1.003, source: { _ in (0, 0) }, sortie: { _, _, _ in }
            )
        }
        XCTAssertEqual(consommees, Int((512.0 * 1.003 * 100).rounded()), accuracy: 2)
    }

    func testLInterpolationRendLeMilieuEntreDeuxEchantillons() {
        XCTAssertEqual(LectureEtiree.meler(0, 100, 0.5), 50)
        XCTAssertEqual(LectureEtiree.meler(-100, 100, 0.5), 0)
        XCTAssertEqual(LectureEtiree.meler(40, 80, 0), 40)
    }

    /// `☠` Sans bornage, un arrondi au-dessus du maximum 16 bits reboucle en
    /// minimum — ce qui s'entend comme un claquement sec.
    func testLInterpolationNeRebouclePasAuxExtremes() {
        XCTAssertEqual(LectureEtiree.meler(.max, .max, 0.5), .max)
        XCTAssertEqual(LectureEtiree.meler(.min, .min, 0.5), .min)
    }

    func testLeBesoinEnTramesComptLaTrameVoisine() {
        let lecteur = LectureEtiree()
        XCTAssertEqual(lecteur.besoinEnTrames(0, facteur: 1), 0)
        XCTAssertEqual(lecteur.besoinEnTrames(256, facteur: 1), 257)
        XCTAssertGreaterThan(lecteur.besoinEnTrames(256, facteur: 1.003), 257)
    }
}
