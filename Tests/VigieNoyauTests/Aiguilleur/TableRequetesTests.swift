import Foundation
import Testing
@testable import VigieNoyau

// La table des requêtes en vol : une réponse peut arriver avant l'attente, un échec ne reste jamais muet.

struct TableRequetesTests {
    private let reponse = ReponseRequete(statut: 200, corps: "{\"machine\":\"noeud-test\"}")

    @Test func reponseArriveeAvantLAttenteEstConservee() async throws {
        let table = TableRequetes()
        await table.prevoir("r1")
        await table.resoudre("r1", reponse)
        #expect(try await table.attendre("r1") == reponse)
    }

    @Test func attenteDebloqueeParLaReponse() async throws {
        let table = TableRequetes()
        await table.prevoir("r2")
        let attente = Task { try await table.attendre("r2") }
        await table.resoudre("r2", reponse)
        #expect(try await attente.value == reponse)
    }

    @Test func echecEstRenduAvecsonMotif() async throws {
        let table = TableRequetes()
        await table.prevoir("r3")
        await table.echouer("r3", ErreurAiguilleur("délai dépassé"))
        await #expect(throws: ErreurAiguilleur.self) { try await table.attendre("r3") }
    }

    @Test func reponseTardiveApresEchecEstIgnoree() async throws {
        let table = TableRequetes()
        await table.prevoir("r4")
        await table.echouer("r4", ErreurAiguilleur("délai dépassé"))
        await table.resoudre("r4", reponse)
        await #expect(throws: ErreurAiguilleur.self) { try await table.attendre("r4") }
    }

    @Test func reponseDUneRefInconnueEstIgnoree() async throws {
        let table = TableRequetes()
        await table.resoudre("inconnue", reponse)
        await table.prevoir("r5")
        await table.resoudre("r5", ReponseRequete(statut: 404, corps: "{}"))
        #expect(try await table.attendre("r5").statut == 404)
    }

    @Test func echouerToutRendLesRequetesEnVol() async throws {
        let table = TableRequetes()
        await table.prevoir("r6")
        await table.prevoir("r7")
        let premiere = Task { try await table.attendre("r6") }
        await table.echouerTout(ErreurAiguilleur("lien coupé"))
        await #expect(throws: ErreurAiguilleur.self) { try await premiere.value }
        await #expect(throws: ErreurAiguilleur.self) { try await table.attendre("r7") }
    }

    @Test func annulerRetireLaRequeteSansFuite() async throws {
        let table = TableRequetes()
        await table.prevoir("r8")
        await table.annuler("r8")
        await table.resoudre("r8", reponse)
        await table.prevoir("r9")
        await table.resoudre("r9", reponse)
        #expect(try await table.attendre("r9") == reponse)
    }
}
