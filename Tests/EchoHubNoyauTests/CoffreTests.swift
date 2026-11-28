import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Coffre de la tour")
struct CoffreTests {
    @Test func decodeLaListeDuCoffre() throws {
        let json = """
        {"secrets":[{"name":"saily-token","kind":"token","note":"Pi","createdAt":1795584547878,"updatedAt":1795585015273}]}
        """
        struct Liste: Decodable { let secrets: [SecretCoffre] }
        let secret = try #require(try JSONDecoder().decode(Liste.self, from: Data(json.utf8)).secrets.first)
        #expect(secret.id == "saily-token")
        #expect(secret.genre == "token")
        #expect(abs(secret.creeLe.timeIntervalSince1970 - 1_795_584_547.878) < 0.001)
    }

    @Test func uneEditionNEnvoieQueCeQuiChange() throws {
        let corps = try JSONEncoder().encode(EditionSecret(note: "nouvelle"))
        let objet = try #require(try JSONSerialization.jsonObject(with: corps) as? [String: String])
        #expect(objet == ["note": "nouvelle"])
    }

    @Test func unNomAEspaceOuBarreResteUnSeulSegment() async throws {
        let client = ClientEchoHub(reglages: ReglagesRelais(adresse: "https://relais.example", jeton: "j"))
        let requete = try await client.requeteRelais("GET", ClientEchoHub.cheminSecret("mon secret/1%"))
        #expect(requete.url?.absoluteString == "https://relais.example/coffre/secrets/mon%20secret%2F1%25")
        #expect(requete.value(forHTTPHeaderField: "Authorization") == "Bearer j")
    }

    @Test func lesRoutesDeLaTourGardentLeurRequete() async throws {
        let client = ClientEchoHub(reglages: ReglagesRelais(adresse: "https://relais.example/", jeton: ""))
        let requete = try await client.requeteRelais("GET", "apercu/ouvrir?port=5173")
        #expect(requete.url?.absoluteString == "https://relais.example/apercu/ouvrir?port=5173")
    }
}
