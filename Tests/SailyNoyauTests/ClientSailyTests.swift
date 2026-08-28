import XCTest
@testable import SailyNoyau

/// Ce qui est éprouvable de `ClientSaily` sans réseau : la construction des URL
/// (le piège du `?` pourcent-encodé) et la dérivation de l'URL WebSocket.
final class ClientSailyTests: XCTestCase {

    func testLaRequeteEstPorteeDuCoteRequete() throws {
        let base = try XCTUnwrap(URL(string: "https://saily.example.com"))
        let url = try XCTUnwrap(ClientSaily.url(base: base, chemin: "items?since=42"))
        XCTAssertEqual(url.path, "/api/items")
        XCTAssertEqual(url.query, "since=42")
        XCTAssertFalse(url.absoluteString.contains("%3F"), "le ? ne doit pas être encodé")
    }

    func testUnCheminSansRequete() throws {
        let base = try XCTUnwrap(URL(string: "https://x.y"))
        let url = try XCTUnwrap(ClientSaily.url(base: base, chemin: "blobs/abc.png"))
        XCTAssertEqual(url.path, "/api/blobs/abc.png")
        XCTAssertNil(url.query)
    }

    func testLUrlSyncDeriveWssEtPorteLeJeton() async {
        let client = ClientSaily(reglages: ReglagesServeur(
            adresse: "https://saily.example.com", jeton: "secret"
        ))
        let url = await client.urlSync()
        let texte = try? XCTUnwrap(url?.absoluteString)
        XCTAssertEqual(url?.scheme, "wss")
        XCTAssertEqual(url?.path, "/sync")
        XCTAssertTrue(texte?.contains("token=secret") ?? false)
    }

    func testLUrlSyncPasseEnWsSurHttp() async {
        let client = ClientSaily(reglages: ReglagesServeur(
            adresse: "http://10.0.0.2:4610", jeton: ""
        ))
        let url = await client.urlSync()
        XCTAssertEqual(url?.scheme, "ws")
        XCTAssertEqual(url?.path, "/sync")
        XCTAssertNil(url?.query, "sans jeton, pas de ?token=")
    }

    func testUneAdresseInvalideNeConstruitPasDeRequete() async {
        let client = ClientSaily(reglages: ReglagesServeur(adresse: "pas une url", jeton: ""))
        do {
            _ = try await client.requete("GET", "items")
            XCTFail("aurait dû lever adresseInvalide")
        } catch let erreur as ErreurSaily {
            XCTAssertEqual(erreur, .adresseInvalide("pas une url"))
        } catch {
            XCTFail("erreur inattendue : \(error)")
        }
    }
}
