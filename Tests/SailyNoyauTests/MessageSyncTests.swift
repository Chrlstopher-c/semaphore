import XCTest
@testable import SailyNoyau

/// Le protocole WebSocket : ces messages sont la seule voix du temps réel. Leur
/// forme est fixée par `contracts.ts` ; un `type` mal écrit ou une clé oubliée
/// coupe la synchro sans un mot.
final class MessageSyncTests: XCTestCase {

    // MARK: - Décodage serveur → client

    func testSnapshotSeDecode() throws {
        let json = """
        {"type":"snapshot","serverTime":1724800000000,"items":[
          {"id":"a","kind":"note","text":"un","url":null,"blob":null,"mime":null,
           "tags":[],"pinned":false,"createdAt":1,"updatedAt":2,"deletedAt":null}
        ]}
        """
        let message = try XCTUnwrap(MessageServeur.decoder(Data(json.utf8)))
        guard case let .snapshot(items, serverTime) = message else {
            return XCTFail("attendu snapshot, reçu \(message)")
        }
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, "a")
        XCTAssertEqual(serverTime, 1724800000000)
    }

    func testUpsertServeurPorteSonOrigin() throws {
        let json = """
        {"type":"upsert","origin":"ios-42","item":
          {"id":"b","kind":"link","text":"","url":"https://z","blob":null,"mime":null,
           "tags":[],"pinned":true,"createdAt":1,"updatedAt":3,"deletedAt":null}}
        """
        let message = try XCTUnwrap(MessageServeur.decoder(Data(json.utf8)))
        guard case let .upsert(item, origin) = message else {
            return XCTFail("attendu upsert")
        }
        XCTAssertEqual(item.id, "b")
        XCTAssertEqual(origin, "ios-42")
    }

    func testDeleteServeurPorteDeletedAt() throws {
        let json = #"{"type":"delete","id":"c","deletedAt":77,"origin":"pc"}"#
        let message = try XCTUnwrap(MessageServeur.decoder(Data(json.utf8)))
        guard case let .delete(id, deletedAt, origin) = message else {
            return XCTFail("attendu delete")
        }
        XCTAssertEqual(id, "c")
        XCTAssertEqual(deletedAt, 77)
        XCTAssertEqual(origin, "pc")
    }

    func testPongSeDecode() throws {
        let message = try XCTUnwrap(
            MessageServeur.decoder(Data(#"{"type":"pong","serverTime":9}"#.utf8))
        )
        guard case let .pong(serverTime) = message else { return XCTFail("attendu pong") }
        XCTAssertEqual(serverTime, 9)
    }

    /// `☠` Un type inconnu ne fait pas tomber la réception : `decoder` rend
    /// `nil`, l'appelant l'ignore. C'est ce qui laisse le serveur ajouter un
    /// message qu'une vieille app ne connaît pas.
    func testUnTypeInconnuRendNil() {
        XCTAssertNil(MessageServeur.decoder(Data(#"{"type":"licorne"}"#.utf8)))
    }

    // MARK: - Encodage client → serveur

    private func objet(_ message: MessageClient) throws -> [String: Any] {
        let donnees = try CodageJSON.encodeur().encode(message)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: donnees) as? [String: Any])
    }

    func testHelloEncodeTypeClientIdSince() throws {
        let objet = try objet(.hello(clientId: "ios-1", since: 12))
        XCTAssertEqual(objet["type"] as? String, "hello")
        XCTAssertEqual(objet["clientId"] as? String, "ios-1")
        XCTAssertEqual(objet["since"] as? Int, 12)
    }

    func testUpsertClientEncodeItemEtClientId() throws {
        let input = ItemInput(id: "u", kind: .note, text: "x")
        let objet = try objet(.upsert(item: input, clientId: "ios-1"))
        XCTAssertEqual(objet["type"] as? String, "upsert")
        XCTAssertEqual(objet["clientId"] as? String, "ios-1")
        XCTAssertNotNil(objet["item"] as? [String: Any])
    }

    func testPingEncodeSeulementSonType() throws {
        let objet = try objet(.ping)
        XCTAssertEqual(objet["type"] as? String, "ping")
        XCTAssertEqual(objet.count, 1)
    }
}
