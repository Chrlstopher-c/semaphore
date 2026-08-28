import Foundation
import Testing

@testable import VigieNoyau

@Suite("Défilement d'un fil — colle au bas et flèche de retour")
struct DefilementTests {

    /// Un fil ordinaire : dix tours de 200 pt dans une fenêtre de 600 pt.
    private func fil(distance: CGFloat) -> EtatDefilement {
        EtatDefilement(
            distanceAuBas: distance, hauteurVisible: 600, hauteurTotale: 2000, messages: 10
        )
    }

    @Test("collé au bas tant qu'il reste moins que la tolérance")
    func colle() {
        #expect(fil(distance: 0).colleAuBas)
        #expect(fil(distance: 59).colleAuBas)
        #expect(!fil(distance: 61).colleAuBas)
    }

    @Test("pas de flèche tant que cinq tours ne sont pas passés sous le pli")
    func silencieuxDePres() {
        // 4 tours de 200 pt sous le pli, et pourtant plus d'un écran : la règle
        // des messages prime.
        #expect(!fil(distance: 800).loinDuBas)
        #expect(fil(distance: 1000).loinDuBas)
    }

    @Test("dans un fil de messages courts, cinq d'entre eux ne suffisent pas")
    func plancherDUnEcran() {
        // 40 tours de 25 pt : cinq font 125 pt, soit un cinquième d'écran.
        let court = EtatDefilement(
            distanceAuBas: 300, hauteurVisible: 600, hauteurTotale: 1000, messages: 40
        )
        #expect(!court.loinDuBas)
        #expect(EtatDefilement(
            distanceAuBas: 700, hauteurVisible: 600, hauteurTotale: 1000, messages: 40
        ).loinDuBas)
    }

    @Test("dans un fil de longs rapports, un seul tour ne déclenche rien")
    func filDeLongsTours() {
        // 3 tours de 1200 pt : il en faudrait cinq, ils ne sont même pas là.
        let long = EtatDefilement(
            distanceAuBas: 2000, hauteurVisible: 600, hauteurTotale: 3600, messages: 3
        )
        #expect(!long.loinDuBas)
    }

    @Test("un fil vide ou pas encore mesuré ne montre jamais de flèche")
    func geometrieAbsente() {
        #expect(!EtatDefilement().loinDuBas)
        #expect(!EtatDefilement(distanceAuBas: 900, hauteurVisible: 600).loinDuBas)
        #expect(!EtatDefilement(
            distanceAuBas: 900, hauteurVisible: 600, hauteurTotale: 2000, messages: 0
        ).loinDuBas)
    }
}
