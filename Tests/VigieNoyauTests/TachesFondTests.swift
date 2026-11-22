import Foundation
import Testing
@testable import VigieNoyau

private func tacheSdk(
    _ id: String, statut: String = "en_cours", type: String = "Bash", sousAgent: String? = nil,
    debut: String = "2026-11-22T10:00:00Z", fin: String? = nil
) throws -> TacheSession {
    let sousJSON = sousAgent.map { "\"\($0)\"" } ?? "null"
    let finJSON = fin.map { "\"\($0)\"" } ?? "null"
    let json = """
    {"id":"\(id)","type":"\(type)","description":"tâche \(id)","statut":"\(statut)","arrierePlan":true,
    "sousAgent":\(sousJSON),"modele":"sonnet","activite":null,"outils":0,"jetons":0,"dureeMs":0,
    "debutLe":"\(debut)","finLe":\(finJSON)}
    """
    return try JSONDecoder().decode(TacheSession.self, from: Data(json.utf8))
}

private func tacheParite(_ id: String, statut: String, debut: String = "2026-11-22T10:00:00Z") throws -> TacheParite {
    let json = """
    {"id":"\(id)","genre":"commande","description":"parité \(id)","statut":"\(statut)",
    "debutLe":"\(debut)","finLe":null,"modele":null,"tacheId":null}
    """
    return try JSONDecoder().decode(TacheParite.self, from: Data(json.utf8))
}

private func pariteAvec(_ taches: [TacheParite], transcript: Bool = true) throws -> PariteSession {
    let liste = try taches.map { try String(decoding: JSONEncoder().encode($0), as: UTF8.self) }
    let json = #"{"transcript":\#(transcript),"taches":[\#(liste.joined(separator: ","))]}"#
    return try JSONDecoder().decode(PariteSession.self, from: Data(json.utf8))
}

@Test func lesTachesDuSdkPrennentLePasSurLaParite() throws {
    let sdk = [try tacheSdk("s1")]
    let parite = try pariteAvec([try tacheParite("p1", statut: "terminee")])
    let fusion = TachesFond.fusion(sdk: sdk, parite: parite)
    #expect(fusion.map(\.id) == ["s1"])
    #expect(fusion.first?.deParite == false)
}

@Test func laPariteSertSeulementSiLeSdkEstVide() throws {
    let parite = try pariteAvec([try tacheParite("p1", statut: "echouee")])
    let fusion = TachesFond.fusion(sdk: [], parite: parite)
    #expect(fusion.map(\.id) == ["p1"])
    #expect(fusion.first?.deParite == true && fusion.first?.arretable == false)
    #expect(fusion.first?.statut == "Échouée" && fusion.first?.enCours == false)
    let sansTranscript = try pariteAvec([try tacheParite("p2", statut: "en_cours")], transcript: false)
    #expect(TachesFond.fusion(sdk: [], parite: sansTranscript).isEmpty)
    #expect(TachesFond.fusion(sdk: [], parite: nil).isEmpty)
}

@Test func genreAgentParSousAgentOuParTypeSinonCommande() throws {
    let sousAgent = try tacheSdk("a", type: "Bash", sousAgent: "explorer")
    let parType = try tacheSdk("b", type: "local_agent")
    let commande = try tacheSdk("c", type: "Bash")
    let fusion = TachesFond.fusion(sdk: [sousAgent, parType, commande], parite: nil)
    let genres = Dictionary(uniqueKeysWithValues: fusion.map { ($0.id, $0.genre) })
    #expect(genres == ["a": .agent, "b": .agent, "c": .commande])
}

@Test func arretableSeulementEnCoursOuEnAttente() throws {
    let taches = [
        try tacheSdk("cours", statut: "en_cours"),
        try tacheSdk("attente", statut: "en_attente"),
        try tacheSdk("pause", statut: "pausee"),
        try tacheSdk("fin", statut: "terminee"),
    ]
    let fusion = TachesFond.fusion(sdk: taches, parite: nil)
    let arretables = Set(fusion.filter(\.arretable).map(\.id))
    #expect(arretables == ["cours", "attente"])
    #expect(Set(fusion.filter(\.enCours).map(\.id)) == ["cours", "attente"])
}

@Test func libellesFrancaisDesStatuts() throws {
    let attendus = [
        "en_attente": "En attente", "en_cours": "En cours", "pausee": "En pause",
        "terminee": "Terminée", "echouee": "Échouée", "arretee": "Arrêtée",
    ]
    for (brut, libelle) in attendus {
        let fusion = TachesFond.fusion(sdk: [try tacheSdk("x", statut: brut)], parite: nil)
        #expect(fusion.first?.statut == libelle, "statut \(brut)")
    }
}

@Test func plusRecenteDabord() throws {
    let taches = [
        try tacheSdk("ancienne", debut: "2026-11-22T08:00:00Z"),
        try tacheSdk("recente", debut: "2026-11-22T11:00:00.500Z"),
        try tacheSdk("milieu", debut: "2026-11-22T09:30:00Z"),
    ]
    #expect(TachesFond.fusion(sdk: taches, parite: nil).map(\.id) == ["recente", "milieu", "ancienne"])
}

@Test func dureeAvecEtSansFin() throws {
    let maintenant = try #require(DateRelative.date("2026-11-22T10:10:00Z"))
    let finie = try TachesFond.fusion(
        sdk: [try tacheSdk("f", statut: "terminee", debut: "2026-11-22T10:00:00Z", fin: "2026-11-22T10:01:30Z")],
        parite: nil
    )
    let enCours = try TachesFond.fusion(sdk: [try tacheSdk("e", debut: "2026-11-22T10:00:00Z")], parite: nil)
    #expect(TachesFond.duree(try #require(finie.first), maintenant: maintenant) == 90)
    #expect(TachesFond.duree(try #require(enCours.first), maintenant: maintenant) == 600)
}

@Test func dureeSansDebutLisibleEstNulle() throws {
    let maintenant = Date()
    let casse = try TachesFond.fusion(sdk: [try tacheSdk("k", debut: "pas-une-date")], parite: nil)
    #expect(TachesFond.duree(try #require(casse.first), maintenant: maintenant) == 0)
}
