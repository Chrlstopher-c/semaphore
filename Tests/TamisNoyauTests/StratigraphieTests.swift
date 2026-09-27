import XCTest
@testable import TamisNoyau

final class StratigraphieTests: XCTestCase {
    func testDesStratesParAnneeEtParMois() {
        let cliches = [
            Aides.cliche("a", Aides.date(2020, 3), poids: 10),
            Aides.cliche("b", Aides.date(2020, 3), poids: 20),
            Aides.cliche("c", Aides.date(2020, 7), poids: 5),
            Aides.cliche("d", Aides.date(2022, 1), poids: 1),
            Aides.cliche("e", nil, poids: 99),
        ]
        let strates = Stratigraphie.calculer(cliches, panier: ["b"], calendrier: Aides.calendrier)
        XCTAssertEqual(strates.map(\.id), [2022, 2020])
        let s2020 = strates[1]
        XCTAssertEqual(s2020.annee.nombre, 3)
        XCTAssertEqual(s2020.annee.poids, 35)
        XCTAssertEqual(s2020.annee.poidsPanier, 20)
        XCTAssertEqual(s2020.mois.map(\.mois), [7, 3])
    }
}
