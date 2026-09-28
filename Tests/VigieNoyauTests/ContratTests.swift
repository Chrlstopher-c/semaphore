import Foundation
import Testing
@testable import VigieNoyau

// Échantillons capturés sur le relais de production le 28/09 (adresses remplacées) : le décodage est éprouvé contre
// ce que le serveur envoie vraiment, pas contre une idée qu'on s'en fait.
private func echantillon(_ nom: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: "Echantillons/\(nom)", withExtension: "json"))
    return try Data(contentsOf: url)
}

@Test func etatDuRelaisDecode() throws {
    let etat = try JSONDecoder().decode(EtatRelais.self, from: try echantillon("etat"))
    #expect(etat.machines.first?.enLigne == true)
    let session = try #require(etat.sessions.first)
    #expect(session.statut == .terminee)
    #expect(session.pilotee)
    #expect(session.contexte.tokens > 0)
}

@Test func filReelDecodeEtSeStructure() throws {
    let evts = try JSONDecoder().decode([EvenementDate].self, from: try echantillon("evenements"))
    #expect(evts.count > 5)
    let fil = StructureFil.structurer(evts)
    let outils = fil.compactMap { if case .outil(let o) = $0 { return o } else { return nil } }
    #expect(!outils.isEmpty)
    #expect(outils.allSatisfy { $0.resultat != nil }, "chaque outil a reçu son résultat")
    #expect(fil.contains { if case .simple(_, _, .objectifAtteint) = $0 { return true } else { return false } })
}

@Test func typeInconnuNeCassePasLeFil() throws {
    let json = #"[{"seq":1,"sessionId":"s","ts":"2026-09-28T00:00:00.000Z","evt":{"type":"futur","x":1}}]"#
    let evts = try JSONDecoder().decode([EvenementDate].self, from: Data(json.utf8))
    #expect(evts.first?.evt == .inconnu(type: "futur"))
}
