import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Retours")
struct RetoursTests {
    @Test func resumeGardeLesIdentifiantsTelsQuels() throws {
        let json = """
        {"total":2,"positifs":1,"negatifs":1,"corrections":0,"comparaisons":0,"par_source":{},
         "par_message":{"msg_a1":"positif","msg_b2":"negatif"},
         "raisons_par_message":{"msg_b2":["fait_invente","ton","inconnue"]},
         "claude_par_message":{"msg_a1":"negatif"}}
        """
        let resume = try Retours.resume(Data(json.utf8))
        #expect(resume.parMessage["msg_a1"] == .positif)
        #expect(resume.raisonsParMessage["msg_b2"] == [.faitInvente, .ton])
        #expect(resume.claudeParMessage["msg_a1"] == .negatif)
    }

    @Test func retoucherLeMemeVerdictLeRetire() {
        #expect(Retours.retire(actuel: .positif, nouveau: .positif, raisons: nil))
        #expect(!Retours.retire(actuel: .negatif, nouveau: .negatif, raisons: [.ton]))
        #expect(!Retours.retire(actuel: .correction, nouveau: .correction, raisons: nil))
        #expect(!Retours.retire(actuel: nil, nouveau: .positif, raisons: nil))
    }

    @Test func texteFinalSansRaisonnement() {
        #expect(Retours.texteFinal("<think>je pense</think>\n Réponse ") == "Réponse")
        #expect(Retours.texteFinal(" Tout ") == "Tout")
    }

    @Test func demandeEnSnakeCase() throws {
        let corps = try CodageJSON.encodeur().encode(DemandeRetour(
            conversationId: "c", messageId: "m", verdict: .negatif, correction: nil, raisons: [.horsBrief]))
        let objet = try #require(JSONSerialization.jsonObject(with: corps) as? [String: Any])
        #expect(objet["message_id"] as? String == "m")
        #expect(objet["raisons"] as? [String] == ["hors_brief"])
    }
}
