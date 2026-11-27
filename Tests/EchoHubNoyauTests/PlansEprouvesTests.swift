import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Plans éprouvés")
struct PlansEprouvesTests {
    @Test func resumeLaLigneDuWeb() throws {
        let json = """
        [{"identifiant":"org/modele","plan":{"moteur":"vllm","contexte":65536,"type_kv_cache":"q8_0","mode_eager":false,"couches_gpu":32},"enregistre_le":null},
         {"identifiant":"autre::f.gguf","plan":{"moteur":"llamacpp","contexte":null,"type_kv_cache":null,"mode_eager":true}}]
        """
        let brut = try CodageOpaque.decodeur().decode(ValeurJSON.self, from: Data(json.utf8))
        let plans = (brut.listeOuNil ?? []).compactMap(PlanEprouve.lire)
        #expect(plans.map(\.identifiant) == ["org/modele", "autre::f.gguf"])
        #expect(plans[0].resume == "vllm · 64 k · q8_0 · graphes")
        #expect(plans[1].resume == "llamacpp · contexte par défaut · cache par défaut · sans graphes")
    }
}
