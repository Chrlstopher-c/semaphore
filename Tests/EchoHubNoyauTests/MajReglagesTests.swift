import XCTest
@testable import EchoHubNoyau

/// Le piège du `PATCH /reglages`, éprouvé sur le fil réel.
///
/// Le backend fusionne avec `exclude_unset` : `max_tokens: null` (« aucun
/// plafond ») et `graine: null` (« aléatoire ») sont des valeurs DEMANDÉES. Un
/// `Optional` Swift ordinaire synthétise `encodeIfPresent` et les enverrait
/// comme des absences — les deux réglages seraient posables et jamais
/// effaçables, sans qu'aucune erreur ne le signale.
final class MajReglagesTests: XCTestCase {

    private func json(_ patch: some Encodable) throws -> String {
        let encodeur = CodageJSON.encodeur()
        encodeur.outputFormatting = .sortedKeys
        return String(decoding: try encodeur.encode(patch), as: UTF8.self)
    }

    // MARK: - Les trois états d'un champ

    func testUnChampAbsentNePartPas() throws {
        XCTAssertEqual(try json(MajReglages()), "{}")
    }

    func testUnChampNulPartEnNull() throws {
        let patch = MajReglages(historiqueMaxMessages: .nul)
        XCTAssertEqual(try json(patch), "{\"historique_max_messages\":null}")
    }

    func testUnChampValuePartAvecSaValeur() throws {
        let patch = MajReglages(historiqueMaxMessages: .valeur(20))
        XCTAssertEqual(try json(patch), "{\"historique_max_messages\":20}")
    }

    // MARK: - Les deux champs qui doivent rester effaçables

    func testMaxTokensEtGraineSEffacentExplicitement() throws {
        let patch = MajParametres(maxTokens: .nul, graine: .nul)
        XCTAssertEqual(try json(patch), "{\"graine\":null,\"max_tokens\":null}")
    }

    func testMaxTokensEtGraineOmisNeTouchentARien() throws {
        XCTAssertEqual(try json(MajParametres(temperature: 0.5)), "{\"temperature\":0.5}")
    }

    /// Le cas nominal de l'écran : on renvoie ce qu'on a lu, `null` compris.
    func testEcrireDesParametresLusConserveLesNull() throws {
        let lus = ParametresEchantillonnage(temperature: 0.7, maxTokens: nil, graine: nil)
        let ecrit = try json(MajParametres(ecrivant: lus))
        XCTAssertTrue(ecrit.contains("\"max_tokens\":null"))
        XCTAssertTrue(ecrit.contains("\"graine\":null"))
        XCTAssertTrue(ecrit.contains("\"temperature\":0.7"))
    }

    func testEcrireUnPlafondPoseLeGarde() throws {
        let lus = ParametresEchantillonnage(maxTokens: 2048, graine: 42)
        let ecrit = try json(MajParametres(ecrivant: lus))
        XCTAssertTrue(ecrit.contains("\"max_tokens\":2048"))
        XCTAssertTrue(ecrit.contains("\"graine\":42"))
    }

    // MARK: - Le prompt système

    /// `null` de premier niveau est FILTRÉ par la fusion serveur, sauf pour
    /// `historique_max_messages`. Vider le prompt se fait avec `""`.
    func testLePromptSeVideAvecUneChaineVidePasAvecNull() throws {
        XCTAssertEqual(try json(MajReglages(promptSysteme: "")), "{\"prompt_systeme\":\"\"}")
        XCTAssertEqual(try json(MajReglages(promptSysteme: nil)), "{}")
    }

    func testUnPatchImbriqueGardeSesDeuxNiveaux() throws {
        let patch = MajReglages(
            promptSysteme: "Réponds court.", parametres: MajParametres(topK: 40)
        )
        XCTAssertEqual(
            try json(patch),
            "{\"parametres\":{\"top_k\":40},\"prompt_systeme\":\"Réponds court.\"}"
        )
    }
}
