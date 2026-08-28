import XCTest
@testable import SailyNoyau

/// Le décodage des `Item` et l'encodage des `ItemInput` sont le contrat avec le
/// serveur : une clé qui glisse casse toute la synchro en silence. Ces tests
/// figent la forme exacte de `contracts.ts`.
final class ItemCodageTests: XCTestCase {

    private func decoder(_ json: String) throws -> Item {
        try CodageJSON.decodeur().decode(Item.self, from: Data(json.utf8))
    }

    func testUnItemNoteSeDecode() throws {
        let item = try decoder("""
        {"id":"a1","kind":"note","text":"salut","url":null,"blob":null,"mime":null,
         "tags":["idée","perso"],"pinned":true,"createdAt":1724800000000,
         "updatedAt":1724800005000,"deletedAt":null}
        """)
        XCTAssertEqual(item.id, "a1")
        XCTAssertEqual(item.kind, .note)
        XCTAssertEqual(item.text, "salut")
        XCTAssertNil(item.url)
        XCTAssertEqual(item.tags, ["idée", "perso"])
        XCTAssertTrue(item.pinned)
        XCTAssertEqual(item.updatedAt, 1724800005000)
        XCTAssertTrue(item.vivant)
    }

    /// `☠` Les espèces portent la valeur du serveur, pas le nom Swift : `link`,
    /// `file`. Un renommage silencieux ici décoderait faux.
    func testLesEspecesMappentLesChainesServeur() throws {
        let lien = try decoder("""
        {"id":"l","kind":"link","text":"","url":"https://x.y","blob":null,"mime":null,
         "tags":[],"pinned":false,"createdAt":1,"updatedAt":1,"deletedAt":null}
        """)
        XCTAssertEqual(lien.kind, .lien)
        XCTAssertEqual(lien.url, "https://x.y")
    }

    func testUnItemSupprimePorteSaPierreTombale() throws {
        let item = try decoder("""
        {"id":"z","kind":"image","text":"","url":null,"blob":"abc.png","mime":"image/png",
         "tags":[],"pinned":false,"createdAt":1,"updatedAt":9,"deletedAt":9}
        """)
        XCTAssertEqual(item.deletedAt, 9)
        XCTAssertFalse(item.vivant)
        XCTAssertEqual(item.blob, "abc.png")
    }

    /// `☠` `url`, `blob` et `mime` DOIVENT sortir avec `null` quand ils sont nil,
    /// jamais absents : le serveur lie ces champs à SQLite et une clé manquante y
    /// arriverait en `undefined`.
    func testInputEmetLesClesNullExplicites() throws {
        let input = ItemInput(id: "n1", kind: .note, text: "hop", tags: ["a"], pinned: false)
        let donnees = try CodageJSON.encodeur().encode(input)
        let objet = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: donnees) as? [String: Any]
        )
        XCTAssertTrue(objet.keys.contains("url"))
        XCTAssertTrue(objet.keys.contains("blob"))
        XCTAssertTrue(objet.keys.contains("mime"))
        XCTAssertTrue(objet["url"] is NSNull)
        XCTAssertEqual(objet["kind"] as? String, "note")
    }

    func testInputDepuisItemRecopieLesChamps() {
        let item = Item(
            id: "i", kind: .lien, text: "t", url: "https://a.b", blob: nil, mime: nil,
            tags: ["x"], pinned: true, createdAt: 1, updatedAt: 2, deletedAt: nil
        )
        let input = ItemInput(depuis: item)
        XCTAssertEqual(input.id, "i")
        XCTAssertEqual(input.kind, .lien)
        XCTAssertEqual(input.url, "https://a.b")
        XCTAssertTrue(input.pinned)
    }
}
