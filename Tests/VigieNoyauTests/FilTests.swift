import Testing
@testable import VigieNoyau

private func fil(_ evts: [Evenement]) -> [EvenementDate] {
    evts.enumerated().map { EvenementDate(seq: $0.offset + 1, sessionId: "s", ts: "2026-09-28T00:00:00.000Z", evt: $0.element) }
}

@Test func sousAgentRegroupeSonTravailEtIgnoreLAccuseDeLancement() {
    let fil = StructureFil.structurer(fil([
        .sousAgent(id: "a1", description: "explorer", modele: "sonnet", genre: "Explore"),
        .resultatOutil(outilId: "a1", extrait: "Async agent launched successfully", erreur: false, agent: nil),
        .outil(id: "t1", nom: "Grep", resume: "x", detail: "{}", agent: "a1"),
        .resultatOutil(outilId: "t1", extrait: "3 fichiers", erreur: false, agent: "a1"),
        .texte(texte: "rapport final", agent: "a1"),
        .texte(texte: "suite", agent: nil),
    ]))
    #expect(fil.count == 2)
    guard case .sousAgent(let agent) = fil[0] else { Issue.record("sous-agent attendu"); return }
    #expect(agent.fin == nil, "l'accusé de lancement n'est pas une fin")
    #expect(agent.nombreOutils == 1)
    #expect(agent.rapport == "rapport final")
    guard case .outil(let o) = agent.interieur[0] else { Issue.record("outil attendu"); return }
    #expect(o.resultat?.extrait == "3 fichiers")
}

@Test func filigraneNeSonnePasLArriereEtIgnoreLesInfos() {
    var f = FiligraneRelais()
    let n = { (seq: Int, niveau: NiveauNotification) in
        NotificationRelais(seq: seq, sessionId: "s", niveau: niveau, titre: "T — objectif atteint", texte: "", ts: "", lue: false)
    }
    #expect(f.retenir([n(1, .important), n(2, .alerte)]).isEmpty, "premier relevé : rien ne sonne")
    let nouvelles = f.retenir([n(2, .alerte), n(3, .info), n(4, .important)])
    #expect(nouvelles.map(\.seq) == [4])
    #expect(TraductionAlerte.projet(pour: n(4, .important)).genre == .objectif)
}

@Test func formatsFrancais() {
    #expect(Format.tokens(51_898) == "52\u{00a0}k")
    #expect(Format.tokens(1_000_000) == "1,0\u{00a0}M")
    #expect(Format.duree(secondes: 90_000) == "1\u{00a0}j 1\u{00a0}h")
}
