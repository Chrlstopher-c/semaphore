import XCTest
@testable import EchoHubNoyau

/// La balise de compaction est un contrat FIGÉ d'EchoHub v2. Ces cas vérifient
/// qu'on la décode aux noms exacts du serveur — en direct (événement SSE) comme
/// au rechargement (`MessageChat.compaction`). Une divergence de nom ici, et la
/// balise disparaît sans le moindre signe.
final class CompactionTests: XCTestCase {

    /// Un vrai JSON du contrat : `snake_case`, date avec fraction et fuseau.
    private static let jsonBalise = """
    {
      "id": "cmp1",
      "conversation_id": "c1",
      "message_id": "m10",
      "coupe_message_id": "m7",
      "nb_messages_resumes": 8,
      "tokens_avant": 210,
      "tokens_apres": 96,
      "contexte_total": 4096,
      "resume": "Objectif : livrer la balise. État : noyau fait.",
      "cree_le": "2026-08-28T06:22:31.123456+00:00"
    }
    """

    func testInfoCompactionDecodeAuxNomsDuContrat() throws {
        let info = try CodageJSON.decodeur().decode(
            InfoCompaction.self, from: Data(Self.jsonBalise.utf8)
        )
        XCTAssertEqual(info.id, "cmp1")
        XCTAssertEqual(info.conversationId, "c1")
        XCTAssertEqual(info.messageId, "m10")
        XCTAssertEqual(info.coupeMessageId, "m7")
        XCTAssertEqual(info.nbMessagesResumes, 8)
        XCTAssertEqual(info.tokensAvant, 210)
        XCTAssertEqual(info.tokensApres, 96)
        XCTAssertEqual(info.contexteTotal, 4096)
        XCTAssertTrue(info.resume.hasPrefix("Objectif"))
    }

    /// L'événement direct : `{ "type": "compaction", "compaction": {…} }`. La
    /// balise se lit sous la clé `compaction`, jamais à plat.
    func testEvenementCompactionEstAiguille() {
        let charge = "{\"type\":\"compaction\",\"compaction\":\(Self.jsonBalise)}"
        guard case .compaction(let info)? = LectureEvenement.lire(
            TrameSSE(evenement: "compaction", donnees: charge)
        ) else {
            return XCTFail("compaction attendue")
        }
        XCTAssertEqual(info.messageId, "m10")
        XCTAssertEqual(info.nbMessagesResumes, 8)
    }

    /// Au rechargement, seul le message assistant qui a déclenché la compaction
    /// porte la balise ; les autres la laissent à `nil`.
    func testMessageAssistantPorteLaBaliseAuRechargement() throws {
        let detail = """
        {
          "conversation": {
            "id": "c1", "titre": "T", "modele_id": "qwen",
            "cree_le": "2026-08-28T06:00:00+00:00", "maj_le": "2026-08-28T06:30:00+00:00",
            "archivee": false, "nb_messages": 2
          },
          "reglages": {
            "prompt_systeme": "", "historique_max_messages": null, "outils_actifs": null,
            "parametres": {
              "temperature": 0.8, "top_p": 0.95, "top_k": 40,
              "penalite_repetition": 1.1, "max_tokens": null,
              "sequences_arret": [], "graine": null
            }
          },
          "messages": [
            {
              "id": "m9", "conversation_id": "c1", "role": "user", "contenu": "salut",
              "cree_le": "2026-08-28T06:10:00+00:00", "interrompu": false,
              "parent_id": null, "compaction": null
            },
            {
              "id": "m10", "conversation_id": "c1", "role": "assistant", "contenu": "bonjour",
              "cree_le": "2026-08-28T06:10:05+00:00", "interrompu": false,
              "parent_id": "m9", "compaction": \(Self.jsonBalise)
            }
          ],
          "feuille_active": "m10", "variantes": {}
        }
        """
        let decodee = try CodageJSON.decodeur().decode(
            ConversationDetaillee.self, from: Data(detail.utf8)
        )
        XCTAssertNil(decodee.messages[0].compaction)
        XCTAssertEqual(decodee.messages[1].compaction?.coupeMessageId, "m7")
    }

    /// Un message sans le champ `compaction` du tout reste valide — le champ est
    /// optionnel, un fil d'avant la compaction ne doit pas casser au décodage.
    func testMessageSansChampCompactionResteValide() throws {
        let brut = """
        {
          "id": "m1", "conversation_id": "c1", "role": "assistant", "contenu": "ok",
          "cree_le": "2026-08-28T06:10:05+00:00", "interrompu": false, "parent_id": null
        }
        """
        let message = try CodageJSON.decodeur().decode(MessageChat.self, from: Data(brut.utf8))
        XCTAssertNil(message.compaction)
    }
}
