import Foundation
import Testing
@testable import VigieNoyau

private func session(titre: String, cwd: String = "/home/chris", objectif: String? = nil) throws -> Session {
    let objectifJSON = objectif.map { "\"\($0)\"" } ?? "null"
    let json = """
    {"id":"s","machine":"tour",
    "projet":{"machine":"tour","chemin":"\(cwd)","nom":"\((cwd as NSString).lastPathComponent)"},
    "cwd":"\(cwd)","titre":"\(titre)","objectif":\(objectifJSON),"modele":"m","compte":"c","autonomie":false,
    "statut":"attente","contexte":{"tokens":1,"max":10},"etapes":0,"compactions":0,"claudeSessionId":null,
    "tmux":null,"attachee":false,"pilotee":false,"creeLe":"2026-11-22T10:00:00Z","majLe":"2026-11-22T10:00:00Z"}
    """
    return try JSONDecoder().decode(Session.self, from: Data(json.utf8))
}

@Test func unVraiTitreResteTel() throws {
    let s = try session(titre: "Refonte de la liste")
    #expect(!TitreSession.estDeRepli(s))
    #expect(TitreSession.affiche(s, premierMessage: "autre") == "Refonte de la liste")
}

@Test func leNomDuDossierNEstPasUnTitre() throws {
    let s = try session(titre: "chris")
    #expect(TitreSession.estDeRepli(s))
    let titre = TitreSession.affiche(s, premierMessage: "\n  Regarde les logs du relais\nmerci")
    #expect(titre == "Regarde les logs du relais")
    #expect(TitreSession.affiche(s, premierMessage: nil) == TitreSession.sansTitre)
    let avecObjectif = try session(titre: "chris", objectif: "Livrer la v1")
    #expect(TitreSession.affiche(avecObjectif, premierMessage: nil) == "Livrer la v1")
}

@Test func premiereLigneCoupeeA80() {
    let long = String(repeating: "a", count: 200)
    #expect(TitreSession.premiereLigne(long).count == 80)
    #expect(TitreSession.premiereLigne(long).hasSuffix("…"))
}

@Test func listeMontreLeTitreDeRepli() throws {
    let s = try session(titre: "chris")
    let lignes = ListeSessions.lignes([s], machines: [], maintenant: Date(), premiersMessages: ["s": "Bonjour"])
    #expect(lignes.first?.titre == "Bonjour")
    #expect(lignes.first?.titreDeRepli == false)
    #expect(ListeSessions.lignes([s], machines: [], maintenant: Date()).first?.titreDeRepli == true)
}

@Test func analyseDeDateRapide() {
    let debut = Date()
    for _ in 0..<2000 { _ = DateRelative.date("2026-11-22T10:00:00.123Z") }
    #expect(Date().timeIntervalSince(debut) < 0.5, "2000 analyses doivent rester sous 0,5 s (formateurs partagés)")
    #expect(DateRelative.date("2026-11-22T10:00:00Z") != nil)
}
