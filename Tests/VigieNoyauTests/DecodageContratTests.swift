import Foundation
import Testing
@testable import VigieNoyau

// Décodage tolérant : un champ facultatif mal formé, un statut inconnu ou une machine incomplète ne cassent rien.

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

private func echantillon(_ nom: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: "Echantillons/\(nom)", withExtension: "json"))
    return try Data(contentsOf: url)
}

/// Une session minimale : seuls les champs qui varient dans ces tests sont paramétrés.
private func sessionJSON(moteur: String?, tmux: String?, statut: String, extra: String = "") -> String {
    let moteurJSON = moteur.map { "\"moteur\": \"\($0)\"," } ?? ""
    let tmuxJSON = tmux.map { "\"\($0)\"" } ?? "null"
    return """
    {"id":"s-1","machine":"alpha","projet":{"machine":"alpha","chemin":"/p","nom":"p"},"cwd":"/p","titre":"T",
    "modele":"m","compte":"c","autonomie":false,"statut":"\(statut)","contexte":{"tokens":1,"max":10},
    "etapes":0,"compactions":0,"tmux":\(tmuxJSON),"attachee":false,"pilotee":true,\(moteurJSON)
    "creeLe":"2026-11-01T08:00:00.000Z","majLe":"2026-11-01T08:00:00.000Z"\(extra)}
    """
}

@Test func statutInconnuDevientAttente() throws {
    #expect(try decode(StatutSession.self, #""statut-futur""#) == .attente)
    #expect(try decode(StatutSession.self, #""question""#) == .question)
}

@Test func champFacultatifMalformeNeFaitPasTomberLaSession() throws {
    let etat = try JSONDecoder().decode(EtatRelais.self, from: try echantillon("etat"))
    let distante = try #require(etat.sessions.last)
    #expect(distante.statut == .attente)
    #expect(distante.rapide == nil)
    #expect(distante.moteur == "claude_ai")
    #expect(distante.distant?.idDistant == "dist-1")
    #expect(distante.pilotable == false)
}

@Test func sessionPilotableSelonMoteurEtTmux() throws {
    let sdk = try decode(Session.self, sessionJSON(moteur: "sdk", tmux: nil, statut: "attente"))
    let tmux = try decode(Session.self, sessionJSON(moteur: "tmux", tmux: "cc-1", statut: "travail"))
    let claudeAi = try decode(Session.self, sessionJSON(moteur: "claude_ai", tmux: "cc-1", statut: "travail"))
    let fermee = try decode(Session.self, sessionJSON(moteur: "sdk", tmux: nil, statut: "fermee"))
    #expect(sdk.pilotable && tmux.pilotable)
    #expect(!claudeAi.pilotable)
    #expect(!fermee.pilotable)
}

@Test func modeEtEffortLisiblesOuAbsents() throws {
    let session = try decode(Session.self, sessionJSON(moteur: "sdk", tmux: nil, statut: "attente",
                                                       extra: #","mode":"default","effort":"xhigh""#))
    #expect(session.modeSession == .defaut)
    #expect(session.effortSession == .xhigh)
    let inconnu = try decode(Session.self, sessionJSON(moteur: nil, tmux: "cc-1", statut: "attente",
                                                       extra: #","mode":"futur","effort":"ultra""#))
    #expect(inconnu.modeSession == nil && inconnu.effortSession == nil)
    #expect(inconnu.mode == "futur", "la valeur brute reste lisible")
}

@Test func permissionDuDialogueDecodeEtSeTolere() throws {
    let base = #"{"id":"d","titre":"Autoriser ?","options":[{"libelle":"Oui","description":""}],"multiple":false,"#
    let permission = #""permission":{"outil":"Bash","entree":"ls","suggestion":true}}"#
    let avec = try decode(Dialogue.self, base + #""saisie":null,"coches":[],"#
        + permission)
    #expect(avec.permission == PermissionDialogue(outil: "Bash", entree: "ls", suggestion: true))
    let casse = try decode(Dialogue.self, base + #""saisie":null,"coches":[],"permission":"n'importe quoi"}"#)
    #expect(casse.permission == nil && casse.options.count == 1)
}

@Test func machineSansEtatLisibleEtComptesFiltres() throws {
    let etat = try JSONDecoder().decode(EtatRelais.self, from: try echantillon("etat"))
    let alpha = try #require(etat.machines.first)
    #expect(alpha.acces?.etat == "local")
    #expect(alpha.etatComptes.count == 2)
    #expect(alpha.etatComptes[0].session?.pourcent == 42.5)
    #expect(alpha.etatComptes[1].session == nil, "une fenêtre mal formée devient absente, le compte reste")
    let beta = try #require(etat.machines.last)
    #expect(beta.etatComptes.isEmpty, "une liste mal formée donne une liste vide")
    #expect(beta.etat == nil && beta.acces?.etat == "injoignable")
}
