import Foundation
import Testing
@testable import VigieNoyau

private func tacheJSON(_ id: String, genre: String = "agent", statut: String = "en_cours") -> String {
    """
    {"id":"\(id)","genre":"\(genre)","description":"tâche \(id)","statut":"\(statut)",
    "debutLe":"2026-11-22T10:00:00.000Z","finLe":null,"modele":"sonnet","tacheId":"x"}
    """
}

private func pariteJSON(_ taches: [String]) -> Data {
    let liste = taches.joined(separator: ",")
    let json = """
    {"transcript":true,"contexte":null,"resultats":[],"taches":[\(liste)],"depot":null}
    """
    return Data(json.utf8)
}

@Test func pariteDecodeLesTachesEtIgnoreLeReste() throws {
    let taches = [tacheJSON("a"), tacheJSON("b", genre: "commande", statut: "terminee")]
    let parite = try JSONDecoder().decode(PariteSession.self, from: pariteJSON(taches))
    #expect(parite.transcript)
    #expect(parite.taches.map(\.id) == ["a", "b"])
    #expect(parite.taches[1].genre == .commande && parite.taches[1].statut == .terminee)
    #expect(parite.taches[0].finLe == nil && parite.taches[0].modele == "sonnet")
}

@Test func uneTacheMalFormeeEstEcartéeSansPerdreLesAutres() throws {
    let mauvaise = #"{"id":3,"genre":"agent","description":"x","statut":"en_cours","debutLe":"t","finLe":null}"#
    let inconnue = tacheJSON("c", statut: "bizarre")
    let taches = [tacheJSON("a"), mauvaise, inconnue, tacheJSON("d")]
    let parite = try JSONDecoder().decode(PariteSession.self, from: pariteJSON(taches))
    #expect(parite.taches.map(\.id) == ["a", "d"])
}

@Test func detailDeTacheGardeLeTacheEtLePrompt() throws {
    let json = """
    {"id":"a","genre":"agent","description":"explorer","statut":"terminee","debutLe":"t","finLe":"u",\
    "modele":null,"tacheId":"ag-1","prompt":"Lis le dépôt","activite":null}
    """
    let detail = try JSONDecoder().decode(DetailTacheParite.self, from: Data(json.utf8))
    #expect(detail.tache.id == "a" && detail.tache.finLe == "u")
    #expect(detail.prompt == "Lis le dépôt" && detail.activite == nil)
}

@Test func routeParite() {
    #expect(Route.parite("s1") == "/api/sessions/s1/parite")
}

@Test func routeTacheParite() {
    #expect(Route.tacheParite("s1", "t9") == "/api/sessions/s1/parite/taches/t9")
}

@Test func routeFichierSession() {
    #expect(Route.fichierSession("s1", "rapport.pdf") == "/api/sessions/s1/fichiers/rapport.pdf")
}
