import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Profils")
struct ProfilsTests {
    @Test func decodeLaListeDuServeur() throws {
        let json = """
        [{"id":"coding","nom":"Coding","style":"Tu es un ingénieur.","outils":null,"parametres":{"temperature":0.6,"top_p":0.95,"top_k":20,"min_p":0.0,"penalite_repetition":1.0,"penalite_presence":0.5,"max_tokens":null,"sequences_arret":[],"graine":null},"mode_projet":true,"hybride":false},
         {"id":"conversation","nom":"Conversation","style":"","outils":["recherche_web"],"parametres":{"temperature":0.7},"mode_projet":false,"hybride":false}]
        """
        let profils = try CodageJSON.decodeur().decode([Profil].self, from: Data(json.utf8))
        #expect(profils.map(\.id) == ["coding", "conversation"])
        #expect(profils[0].edition.modeProjet)
        #expect(profils[0].edition.outils == nil)
        #expect(profils[1].edition.outils == ["recherche_web"])
        #expect(profils[1].edition.parametres.temperature == 0.7)
    }

    @Test func ecritOutilsNullEtCleSnakeCase() throws {
        let corps = try CodageJSON.encodeur().encode(EditionProfil(nom: "Essai", modeProjet: true))
        let objet = try #require(JSONSerialization.jsonObject(with: corps) as? [String: Any])
        #expect(objet["outils"] is NSNull)
        #expect(objet["mode_projet"] as? Bool == true)
        #expect((objet["parametres"] as? [String: Any])?["min_p"] != nil)
    }

    @Test func liaisonNullExplicite() {
        #expect(String(decoding: DepotProfils.corpsLiaison(nil), as: UTF8.self) == "{\"profil_id\":null}")
        #expect(String(decoding: DepotProfils.corpsLiaison("coding"), as: UTF8.self) == "{\"profil_id\":\"coding\"}")
    }
}
