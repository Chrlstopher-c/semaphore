import XCTest
@testable import EchoHubNoyau

/// Le plan de chargement fait un aller-retour SANS être compris : l'app le relit
/// du PC et le lui repose tel quel. Ce qui doit être prouvé n'est donc pas qu'on
/// sait le lire, c'est qu'on ne l'abîme pas en le retraversant.
final class ValeurJSONTests: XCTestCase {

    private func allerRetour(_ json: String) throws -> String {
        let valeur = try CodageOpaque.decodeur().decode(ValeurJSON.self, from: Data(json.utf8))
        let encodeur = CodageOpaque.encodeur()
        encodeur.outputFormatting = .sortedKeys
        return String(decoding: try encodeur.encode(valeur), as: UTF8.self)
    }

    /// `☠` Le cas qui casserait le chargement en silence : `couches_gpu`
    /// réémis en `41.0` là où pydantic attend un entier. L'erreur remontée ne
    /// parlerait pas du voyage aller-retour.
    func testUnEntierResteUnEntier() throws {
        XCTAssertEqual(try allerRetour("{\"couches_gpu\":41}"), "{\"couches_gpu\":41}")
    }

    func testUnFlottantResteUnFlottant() throws {
        XCTAssertEqual(
            try allerRetour("{\"utilisation_memoire_gpu\":0.85}"),
            "{\"utilisation_memoire_gpu\":0.85}"
        )
    }

    /// Les clés snake_case du serveur ne doivent PAS être converties : c'est
    /// tout l'objet de `CodageOpaque`, distinct de `CodageJSON`.
    func testLesClesDuServeurNeSontPasConverties() throws {
        let json = "{\"flash_attention\":true,\"type_cache_kv\":\"q8_0\"}"
        XCTAssertEqual(try allerRetour(json), json)
    }

    func testUneStructureImbriqueeTraverseIntacte() throws {
        let json = "{\"budget\":{\"libre\":12,\"postes\":[1,2,3]},\"moteur\":{\"valeur\":\"llama\"}}"
        XCTAssertEqual(try allerRetour(json), json)
    }

    func testUnNullResteUnNull() throws {
        XCTAssertEqual(try allerRetour("{\"experts_deportes\":null}"), "{\"experts_deportes\":null}")
    }

    func testUneListeVideResteVide() throws {
        XCTAssertEqual(try allerRetour("{\"avertissements\":[]}"), "{\"avertissements\":[]}")
    }

    func testUnBooleenNEstPasLuCommeUnNombre() throws {
        let valeur = try CodageOpaque.decodeur().decode(
            ValeurJSON.self, from: Data("true".utf8)
        )
        XCTAssertEqual(valeur, .booleen(true))
    }

    // MARK: - Traversée

    func testIndicerUnObjet() throws {
        let valeur = try CodageOpaque.decodeur().decode(
            ValeurJSON.self, from: Data("{\"plan\":{\"identifiant_modele\":\"a/b\"}}".utf8)
        )
        XCTAssertEqual(valeur["plan"]?["identifiant_modele"]?.texteOuNil, "a/b")
    }

    /// Indicer ce qui n'est pas un objet rend `nil`, jamais une erreur : ce type
    /// sert à traverser, pas à valider.
    func testIndicerCeQuiNestPasUnObjetRendNil() {
        XCTAssertNil(ValeurJSON.texte("x")["plan"])
        XCTAssertNil(ValeurJSON.nul["plan"])
    }

    /// Le serveur rend `null` pour un modèle qui n'est pas au format GGUF : il
    /// n'y a alors rien à planifier, et ça doit se reconnaître.
    func testUnModeleSansMetadonneesSeReconnait() throws {
        let valeur = try CodageOpaque.decodeur().decode(ValeurJSON.self, from: Data("null".utf8))
        XCTAssertTrue(valeur.estNul)
    }
}
