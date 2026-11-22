import Foundation
import Testing
@testable import VigieNoyau

// Dates relatives, liste des sessions et résumés d'outils : ce qu'on affiche, à partir de données synthétiques.

private let utc = TimeZone(identifier: "UTC") ?? .current
private let maintenant = DateRelative.date("2026-11-22T12:00:00Z") ?? Date()

private func relatif(_ iso: String) -> String {
    DateRelative.texte(iso: iso, maintenant: maintenant, fuseau: utc)
}

@Test func dateRelativeAuxBonnesEchelles() {
    #expect(relatif("2026-11-22T11:59:30Z") == "maintenant")
    #expect(relatif("2026-11-22T11:55:00Z") == "5 min")
    #expect(relatif("2026-11-22T09:00:00Z") == "3 h")
    #expect(relatif("2026-11-22T09:30:00.500Z") == "2 h", "les heures entières s'arrondissent par le bas")
    #expect(relatif("2026-11-21T10:00:00Z") == "hier")
    #expect(relatif("2026-11-10T10:00:00Z") == "10 nov.")
    #expect(relatif("2026-03-03T10:00:00Z") == "3 mars")
    #expect(relatif("2025-11-10T10:00:00.000Z") == "10 nov. 2025")
}

@Test func dateIllisibleDonneChaineVide() {
    #expect(relatif("pas une date") == "")
    #expect(relatif("") == "")
}

private func session(id: String, machine: String, statut: String, majLe: String, archivee: Bool = false,
                     moteur: String? = nil, dialogue: Bool = false) throws -> Session {
    let moteurJSON = moteur.map { "\"moteur\":\"\($0)\"," } ?? ""
    let dialogueJSON = dialogue
        ? #","dialogue":{"id":"d","titre":"?","options":[{"libelle":"Oui","description":""}],"#
        + #""multiple":false,"saisie":null,"coches":[]}"#
        : ""
    let json = """
    {"id":"\(id)","machine":"\(machine)","projet":{"machine":"\(machine)","chemin":"/p","nom":"p"},"cwd":"/p",
    "titre":"Titre \(id)","modele":"m","compte":"c","autonomie":false,"statut":"\(statut)",
    "contexte":{"tokens":1,"max":10},"etapes":0,"compactions":0,"tmux":"cc","attachee":false,
    "pilotee":true,\(moteurJSON)
    "archivee":\(archivee),"nonLue":true,"creeLe":"2026-11-01T08:00:00.000Z","majLe":"\(majLe)"\(dialogueJSON)}
    """
    return try JSONDecoder().decode(Session.self, from: Data(json.utf8))
}

private func machine(id: String, description: String, enLigne: Bool) throws -> Machine {
    let json = """
    {"id":"\(id)","description":"\(description)","racines":[],"projets":[],"comptes":[],"version":"2",
    "derniereVue":"2026-11-22T11:00:00Z","enLigne":\(enLigne)}
    """
    return try JSONDecoder().decode(Machine.self, from: Data(json.utf8))
}

@Test func listeExclutLesArchiveesEtTrieParMajLe() throws {
    let machines = [try machine(id: "alpha", description: "Poste principal", enLigne: true)]
    let sessions = [
        try session(id: "ancienne", machine: "alpha", statut: "attente", majLe: "2026-11-20T10:00:00Z"),
        try session(id: "rangee", machine: "alpha", statut: "attente", majLe: "2026-11-22T11:00:00Z", archivee: true),
        try session(id: "recente", machine: "alpha", statut: "attente", majLe: "2026-11-22T11:50:00Z"),
    ]
    let lignes = ListeSessions.lignes(sessions, machines: machines, maintenant: maintenant, fuseau: utc)
    #expect(lignes.map(\.id) == ["recente", "ancienne"])
}

@Test func statutEtSousTitreSelonLeStatutDeLaSession() throws {
    let machines = [try machine(id: "alpha", description: "Poste principal", enLigne: true)]
    let maj = "2026-11-22T11:55:00Z"
    let sessions = [
        try session(id: "a", machine: "alpha", statut: "travail", majLe: maj),
        try session(id: "b", machine: "alpha", statut: "attente", majLe: maj, dialogue: true),
        try session(id: "c", machine: "alpha", statut: "erreur", majLe: maj),
        try session(id: "d", machine: "alpha", statut: "terminee", majLe: maj),
        try session(id: "e", machine: "alpha", statut: "fermee", majLe: maj),
    ]
    let lignes = ListeSessions.lignes(sessions, machines: machines, maintenant: maintenant, fuseau: utc)
    let parId = Dictionary(uniqueKeysWithValues: lignes.map { ($0.id, $0) })
    #expect(parId["a"]?.statut == .travail && parId["a"]?.sousTitre == "5 min")
    #expect(parId["b"]?.statut == .question && parId["b"]?.sousTitre == "Attend ta réponse · 5 min")
    #expect(parId["c"]?.statut == .erreur && parId["c"]?.sousTitre == "Arrêtée · erreur")
    #expect(parId["d"]?.statut == .repos && parId["d"]?.sousTitre == "Terminée · 5 min")
    #expect(parId["e"]?.sousTitre == "5 min")
    #expect(parId["a"]?.nonLue == true)
}

@Test func appareilSelonLeNomDeLaMachine() throws {
    let machines = [
        try machine(id: "tour", description: "Tour de travail", enLigne: true),
        try machine(id: "x1", description: "Portable de Chris", enLigne: false),
        try machine(id: "pi", description: "Raspberry Pi", enLigne: true),
        try machine(id: "z", description: "Machine inconnue", enLigne: true),
    ]
    let sessions = [
        try session(id: "1", machine: "tour", statut: "attente", majLe: "2026-11-22T11:00:00Z"),
        try session(id: "2", machine: "x1", statut: "attente", majLe: "2026-11-22T10:00:00Z"),
        try session(id: "3", machine: "pi", statut: "attente", majLe: "2026-11-22T09:00:00Z"),
        try session(id: "4", machine: "z", statut: "attente", majLe: "2026-11-22T08:00:00Z"),
        try session(id: "5", machine: "z", statut: "attente", majLe: "2026-11-22T07:00:00Z", moteur: "claude_ai"),
    ]
    let lignes = ListeSessions.lignes(sessions, machines: machines, maintenant: maintenant, fuseau: utc)
    let parId = Dictionary(uniqueKeysWithValues: lignes.map { ($0.id, $0) })
    #expect(parId["1"]?.appareil == .tour && parId["1"]?.appareilEnLigne == true)
    #expect(parId["2"]?.appareil == .portable && parId["2"]?.appareilEnLigne == false)
    #expect(parId["3"]?.appareil == .pi)
    #expect(parId["4"]?.appareil == .autre)
    #expect(parId["5"]?.appareil == .nuage)
}
