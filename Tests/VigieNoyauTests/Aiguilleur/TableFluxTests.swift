import Foundation
import Testing
@testable import VigieNoyau

// La table des réponses en flux : l'en-tête rend le flux, les morceaux arrivent dans l'ordre, la fin dit si le flux
// est complet ; une réponse entière rend un flux d'un seul bloc ; une référence non déclarée n'est jamais servie.

private func reunir(_ flux: AsyncThrowingStream<Data, Error>) async throws -> Data {
    var sortie = Data()
    for try await bloc in flux { sortie.append(bloc) }
    return sortie
}

struct TableFluxTests {
    @Test func morceauxAuFilDeLEauPuisFinComplet() async throws {
        let table = TableFlux()
        await table.prevoir("f1")
        let attente = Task { try await table.attendre("f1") }
        #expect(await table.ouvrir("f1", statut: 200, type: "audio/L16") == true)
        let reponse = try await attente.value
        #expect(reponse.statut == 200)
        #expect(reponse.type == "audio/L16")
        #expect(await table.morceau("f1", rang: 0, base64: Data([1, 2]).base64EncodedString()) == true)
        #expect(await table.morceau("f1", rang: 1, base64: Data([3]).base64EncodedString()) == true)
        await table.fin("f1", morceaux: 2, ok: true)
        #expect(try await reunir(reponse.octets) == Data([1, 2, 3]))
    }

    @Test func premierOctetRenduAvantLaFin() async throws {
        let table = TableFlux()
        await table.prevoir("f2")
        let attente = Task { try await table.attendre("f2") }
        _ = await table.ouvrir("f2", statut: 200, type: "audio/L16")
        let reponse = try await attente.value
        var iterateur = reponse.octets.makeAsyncIterator()
        _ = await table.morceau("f2", rang: 0, base64: Data([9]).base64EncodedString())
        #expect(try await iterateur.next() == Data([9]))
        _ = await table.morceau("f2", rang: 1, base64: Data([8]).base64EncodedString())
        #expect(try await iterateur.next() == Data([8]))
    }

    @Test func morceauHorsOrdreCasseLeFlux() async throws {
        let table = TableFlux()
        await table.prevoir("f3")
        let attente = Task { try await table.attendre("f3") }
        _ = await table.ouvrir("f3", statut: 200, type: "audio/L16")
        let reponse = try await attente.value
        _ = await table.morceau("f3", rang: 1, base64: Data([1]).base64EncodedString())
        await #expect(throws: ErreurAiguilleur.self) { try await reunir(reponse.octets) }
    }

    @Test func finAnnoncantUnAutreNombreOuNokCasseLeFlux() async throws {
        let table = TableFlux()
        await table.prevoir("f4")
        let attente = Task { try await table.attendre("f4") }
        _ = await table.ouvrir("f4", statut: 200, type: "audio/L16")
        let reponse = try await attente.value
        _ = await table.morceau("f4", rang: 0, base64: Data([1]).base64EncodedString())
        await table.fin("f4", morceaux: 2, ok: true)
        await #expect(throws: ErreurAiguilleur.self) { try await reunir(reponse.octets) }
    }

    @Test func reponseEntiereRendUnFluxDUnSeulBloc() async throws {
        let table = TableFlux()
        await table.prevoir("f5")
        let attente = Task { try await table.attendre("f5") }
        #expect(await table.entier("f5", statut: 200, type: "audio/mpeg", octets: Data([7, 7])) == true)
        let reponse = try await attente.value
        #expect(reponse.type == "audio/mpeg")
        #expect(try await reunir(reponse.octets) == Data([7, 7]))
    }

    @Test func referenceNonDeclareeNEstPasServie() async throws {
        let table = TableFlux()
        #expect(await table.ouvrir("inconnue", statut: 200, type: nil) == false)
        #expect(await table.entier("inconnue", statut: 200, type: nil, octets: Data()) == false)
        #expect(await table.morceau("inconnue", rang: 0, base64: "") == false)
    }

    @Test func delaiDeLEnTeteSansEnTeteEchoue() async throws {
        let table = TableFlux()
        await table.prevoir("f6")
        await table.echouer("f6", ErreurAiguilleur("pas de réponse du nœud"))
        await #expect(throws: ErreurAiguilleur.self) { try await table.attendre("f6") }
    }

    @Test func delaiApresEnTeteNeCoupePasLeFlux() async throws {
        let table = TableFlux()
        await table.prevoir("f7")
        let attente = Task { try await table.attendre("f7") }
        _ = await table.ouvrir("f7", statut: 200, type: "audio/L16")
        let reponse = try await attente.value
        await table.echouer("f7", ErreurAiguilleur("pas de réponse du nœud"))
        _ = await table.morceau("f7", rang: 0, base64: Data([5]).base64EncodedString())
        await table.fin("f7", morceaux: 1, ok: true)
        #expect(try await reunir(reponse.octets) == Data([5]))
    }

    @Test func liensCouperLesFluxEnCoursEtLesEntetesAttendus() async throws {
        let table = TableFlux()
        await table.prevoir("f8")
        await table.prevoir("f9")
        let enTete = Task { try await table.attendre("f8") }
        await table.echouerTout(ErreurAiguilleur("lien coupé"))
        await #expect(throws: ErreurAiguilleur.self) { try await enTete.value }
        await table.prevoir("f10")
        let attente = Task { try await table.attendre("f10") }
        _ = await table.ouvrir("f10", statut: 200, type: "audio/L16")
        let reponse = try await attente.value
        await table.echouerTout(ErreurAiguilleur("lien coupé"))
        await #expect(throws: ErreurAiguilleur.self) { try await reunir(reponse.octets) }
    }
}

struct ProtocoleFluxTests {
    @Test func apiFluxEtApiFinSeDecodent() throws {
        let flux = Data(#"{"t":"api_flux","ref":"r1","statut":200,"type":"audio/L16;rate=24000;channels=1"}"#.utf8)
        #expect(try ProtocoleAiguilleur.decoderDuLien(flux)
            == .apiFlux(ref: "r1", statut: 200, type: "audio/L16;rate=24000;channels=1"))
        let fin = Data(#"{"t":"api_fin","ref":"r1","morceaux":3,"ok":false}"#.utf8)
        #expect(try ProtocoleAiguilleur.decoderDuLien(fin) == .apiFin(ref: "r1", morceaux: 3, ok: false))
    }

    @Test func apiFinSansOkEstHorsProtocole() {
        let fin = Data(#"{"t":"api_fin","ref":"r1","morceaux":3}"#.utf8)
        #expect(throws: ErreurChiffrement.self) { try ProtocoleAiguilleur.decoderDuLien(fin) }
    }
}
