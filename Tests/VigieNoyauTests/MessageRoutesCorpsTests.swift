import Foundation
import Testing
@testable import VigieNoyau

// Le WebSocket `/api/flux`, les chemins exacts des routes de session, et les corps envoyés ou reçus.

private func messages() throws -> [MessageClient] {
    let url = try #require(Bundle.module.url(forResource: "Echantillons/messages", withExtension: "json"))
    return try JSONDecoder().decode([MessageClient].self, from: Data(contentsOf: url))
}

/// Clés triées : l'ordre de `JSONEncoder` n'est pas garanti sous Linux (test instable sans ça).
private func json<T: Encodable>(_ valeur: T) throws -> String {
    let encodeur = JSONEncoder()
    encodeur.outputFormatting = .sortedKeys
    return String(decoding: try encodeur.encode(valeur), as: UTF8.self)
}

@Test func chaqueGenreDeMessageDuFluxSeDecode() throws {
    let recus = try messages()
    #expect(recus.count == 9)
    #expect(recus[0] == .evenement(EvenementDate(seq: 7, sessionId: "s-1", ts: "2026-11-01T10:00:00.000Z",
                                                  evt: .texte(texte: "Bonjour.", agent: nil))))
    #expect(recus[1] == .flux(sessionId: "s-1", bloc: "b-3", delta: "Bon", genre: "texte", agent: nil))
    #expect(recus[2] == .flux(sessionId: "s-1", bloc: "b-4", delta: "Hum", genre: "reflexion", agent: "a-1"))
    guard case .session(let session) = recus[3] else { Issue.record("session attendue"); return }
    #expect(session.id == "s-1" && session.statut == .attente)
    #expect(recus[4] == .supprimee(id: "s-0"))
    guard case .machine(let machine) = recus[5] else { Issue.record("machine attendue"); return }
    #expect(machine.id == "alpha" && machine.enLigne)
    guard case .notification(let notification) = recus[6] else { Issue.record("notification attendue"); return }
    #expect(notification.niveau == .important)
    #expect(recus[7] == .filModifie(sessionId: "s-1"))
    #expect(recus[8] == .inconnu(type: "contrat-futur"))
}

@Test func messageMalFormeOuSansTypeDevientInconnu() throws {
    let casse = try JSONDecoder().decode(MessageClient.self, from: Data(#"{"type":"supprimee"}"#.utf8))
    #expect(casse == .inconnu(type: "supprimee"))
    let vide = try JSONDecoder().decode(MessageClient.self, from: Data(#"{"sessionId":"s"}"#.utf8))
    #expect(vide == .inconnu(type: ""))
}

@Test func cheminsDeSessionExacts() {
    #expect(Route.evenementsAvant("s1", avant: 10, limite: 50) == "/api/sessions/s1/evenements?avant=10&limite=50")
    #expect(Route.contexte("s1") == "/api/sessions/s1/contexte")
    #expect(Route.taches("s1") == "/api/sessions/s1/taches")
    #expect(Route.arreterTache("s1", "t9") == "/api/sessions/s1/taches/t9/arreter")
    #expect(Route.modele("s1") == "/api/sessions/s1/modele")
    #expect(Route.effort("s1") == "/api/sessions/s1/effort")
    #expect(Route.mode("s1") == "/api/sessions/s1/mode")
    #expect(Route.renommerSession("s1") == "/api/sessions/s1/renommer")
    #expect(Route.ultracode("s1") == "/api/sessions/s1/ultracode")
    #expect(Route.projets("alpha") == "/api/machines/alpha/projets")
}

@Test func cheminsGlobauxExacts() {
    #expect(Route.flux == "/api/flux")
    #expect(Route.appairer == "/api/appareils/appairer")
    #expect(Route.environnements == "/api/environnements")
    #expect(Route.action("s1", .marquerLue) == "/api/sessions/s1/marquer_lue")
    #expect(Route.action("s1", .epingler) == "/api/sessions/s1/epingler")
}

@Test func corpsEffortEnvoieNullQuandLeDefautReprend() throws {
    #expect(try json(CorpsEffort(effort: nil)) == #"{"effort":null}"#)
    #expect(try json(CorpsEffort(effort: "high")) == #"{"effort":"high"}"#)
}

@Test func corpsSimplesEtAppairage() throws {
    #expect(try json(CorpsTexte(texte: "salut")) == #"{"texte":"salut"}"#)
    #expect(try json(CorpsMode(mode: "plan")) == #"{"mode":"plan"}"#)
    #expect(try json(CorpsActif(actif: true)) == #"{"actif":true}"#)
    #expect(try json(CorpsAppairage(code: "c-1", nom: "iPhone")) == #"{"code":"c-1","nom":"iPhone"}"#)
    let reponse = try JSONDecoder().decode(ReponseAppairage.self, from: Data(#"{"cle":"k-42"}"#.utf8))
    #expect(reponse.cle == "k-42")
}

@Test func demandeOuvertureOmetLesChampsNonPosés() throws {
    let projet = Projet(machine: "alpha", chemin: "/p", nom: "p")
    let simple = DemandeOuverture(machine: "alpha", projet: projet, message: "m", titre: nil, objectif: nil,
                                  autonomie: true, modele: nil)
    let texte = try json(simple)
    #expect(!texte.contains("mode") && !texte.contains("effort") && !texte.contains("ultracode"))
    let complete = DemandeOuverture(machine: "alpha", projet: projet, message: "m", titre: nil, objectif: nil,
                                    autonomie: true, modele: nil, mode: "plan", effort: "low", ultracode: true)
    let avec = try json(complete)
    #expect(avec.contains(#""mode":"plan""#))
    #expect(avec.contains(#""effort":"low""#) && avec.contains(#""ultracode":true"#))
}
