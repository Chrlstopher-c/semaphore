import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Faisabilité d'une variante")
struct FaisabiliteTests {
    let budget = Faisabilite.Budget(vramLibreOctets: 10, ramDisponibleOctets: 20)

    @Test func troisVerdicts() {
        #expect(Faisabilite.evaluer(poidsOctets: 8, budget: budget) == .tientVram)
        #expect(Faisabilite.evaluer(poidsOctets: 25, budget: budget) == .debordeRam)
        #expect(Faisabilite.evaluer(poidsOctets: 31, budget: budget) == .neTientPas)
        #expect(Faisabilite.evaluer(poidsOctets: nil, budget: budget) == .indeterminee)
        #expect(Faisabilite.evaluer(poidsOctets: 8, budget: nil) == .indeterminee)
    }

    @Test func budgetLuDansLeProfil() throws {
        let json = #"{"a_gpu":true,"gpu_principal":{"vram_libre_octets":744095744},"memoire":{"disponible_octets":33453785088}}"#
        let profil = try CodageOpaque.decodeur().decode(ValeurJSON.self, from: Data(json.utf8))
        #expect(Faisabilite.Budget.depuis(profil: profil) == .init(vramLibreOctets: 744095744, ramDisponibleOctets: 33453785088))
        let sansGpu = try CodageOpaque.decodeur().decode(ValeurJSON.self, from: Data(#"{"a_gpu":false}"#.utf8))
        #expect(Faisabilite.Budget.depuis(profil: sansGpu) == nil)
    }
}
