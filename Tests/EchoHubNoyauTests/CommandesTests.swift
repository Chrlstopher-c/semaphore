import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Commandes du chat")
struct CommandesTests {
    private let catalogue = [
        DefinitionCommande(nom: "compact", usage: "/compact [consignes]", description: "", arguments: true),
        DefinitionCommande(nom: "clear", usage: "/clear", description: "", arguments: false),
    ]

    @Test func lectureDeLaSaisie() {
        #expect(AnalyseSaisie("bonjour /compact") == .texte)
        #expect(AnalyseSaisie("//compact") == .litteral("/compact"))
        #expect(AnalyseSaisie("/Compact  garde les endpoints ") == .commande(nom: "compact", arguments: "garde les endpoints"))
        #expect(AnalyseSaisie("/clear") == .commande(nom: "clear", arguments: ""))
    }

    @Test func paletteSeulementPendantLeNom() {
        #expect(AnalyseSaisie.nomEnFrappe("/co") == "co")
        #expect(AnalyseSaisie.nomEnFrappe("/compact x") == nil)
        #expect(AnalyseSaisie.nomEnFrappe("//co") == nil)
        #expect(AnalyseSaisie.filtrer(catalogue, "c").map(\.nom) == ["compact", "clear"])
        #expect(AnalyseSaisie.filtrer(catalogue, "le").map(\.nom) == ["clear"])
        #expect(AnalyseSaisie.completion(catalogue[0]) == "/compact ")
        #expect(AnalyseSaisie.completion(catalogue[1]) == "/clear")
    }

    @Test func reponseDuClearEtEtapesDuCompact() throws {
        let clear = #"{"commande_id":"c1","nom":"clear","effacement":{"id":"e1","ancre_message_id":"m9","cree_le":"2026-11-28T10:00:00Z"}}"#
        let reponse = try CodageJSON.decodeur().decode(ReponseCommande.self, from: Data(clear.utf8))
        #expect(reponse.effacement?.ancreMessageId == "m9")
        let compact = #"{"commande_id":"c2","nom":"compact"}"#
        #expect(try CodageJSON.decodeur().decode(ReponseCommande.self, from: Data(compact.utf8)).effacement == nil)
    }
}
