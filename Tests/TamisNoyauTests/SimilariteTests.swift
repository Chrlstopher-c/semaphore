import XCTest
@testable import TamisNoyau

final class SimilariteTests: XCTestCase {
    private func empreinte(_ id: String, _ minute: Int, _ v: [Float]) -> Empreinte {
        Empreinte(id: id, date: Aides.date(2024, 1, 1, minute), brut: v)!
    }

    func testUneEmpreinteNulleEstRefusee() {
        XCTAssertNil(Empreinte(id: "z", date: Date(), brut: [0, 0]))
    }

    func testLaFenetreBorneLesComparaisons() {
        var r = Regroupeur(fenetre: 600, plancher: 0.8)
        XCTAssertTrue(r.ajouter(empreinte("a", 0, [1, 0])).isEmpty)
        XCTAssertEqual(r.ajouter(empreinte("b", 5, [1, 0.1])).map(\.a), ["a"])
        // Trente minutes plus tard, identique mais hors fenêtre.
        XCTAssertTrue(r.ajouter(empreinte("c", 40, [1, 0])).isEmpty)
    }

    func testLesDissemblablesNeFormentPasDePaire() {
        var r = Regroupeur()
        _ = r.ajouter(empreinte("a", 0, [1, 0]))
        XCTAssertTrue(r.ajouter(empreinte("b", 1, [0, 1])).isEmpty)
    }

    func testLesGrappesSuiventLeSeuil() {
        let paires = [
            Paire(a: "a", b: "b", similarite: 0.95),
            Paire(a: "b", b: "c", similarite: 0.90),
            Paire(a: "x", b: "y", similarite: 0.99),
        ]
        XCTAssertEqual(Grappes.former(paires, seuil: 0.85), [["a", "b", "c"], ["x", "y"]])
        XCTAssertEqual(Grappes.former(paires, seuil: 0.93), [["a", "b"], ["x", "y"]])
    }

    func testDoublonsExacts() {
        let d = Aides.date(2023)
        let groupes = Grappes.doublonsExacts([
            Aides.cliche("a", d, poids: 7), Aides.cliche("b", d, poids: 7),
            Aides.cliche("c", d, poids: 8), Aides.cliche("d", d, poids: nil), Aides.cliche("e", d, poids: nil),
        ])
        XCTAssertEqual(groupes, [["a", "b"]])
    }

    func testLElectionPrefereLeFavoriPuisLeScore() {
        let cliches = Dictionary(uniqueKeysWithValues: [
            Aides.cliche("a", nil, pixels: 900), Aides.cliche("b", nil), Aides.cliche("c", nil, traits: [.favori]),
        ].map { ($0.id, $0) })
        let q = ["a": Qualite(score: -0.5, utilitaire: false), "b": Qualite(score: 0.6, utilitaire: false)]
        XCTAssertEqual(Election.meilleur(["a", "b", "c"], cliches: cliches, qualites: q), "c")
        XCTAssertEqual(Election.meilleur(["a", "b"], cliches: cliches, qualites: q), "b")
        XCTAssertEqual(Election.surplus(["a", "b"], cliches: cliches, qualites: q), ["a"])
        XCTAssertEqual(Election.meilleur(["a", "b"], cliches: cliches, qualites: [:]), "a")
    }
}
