import Foundation
import Testing
@testable import VigieNoyau

// Résumés d'outils au format de Desktop, blocs du fil (suites d'actions, tâches fusionnées) et détail d'un appel.

@Test func resumeDesFamillesEtDesMcp() {
    #expect(ResumeOutils.resume(noms: ["Bash", "Bash", "Read"]) == "Exécuté 2 commandes, lu 1 fichier")
    #expect(ResumeOutils.resume(noms: ["Bash", "Read", "Edit", "Grep"])
        == "Exécuté 1 commande, lu 1 fichier, modifié 1 fichier, et 1 autre action")
    #expect(ResumeOutils.resume(noms: ["Bash", "Read", "Edit", "Grep", "Glob"])
        == "Exécuté 1 commande, lu 1 fichier, modifié 1 fichier, et 2 autres actions")
    #expect(ResumeOutils.resume(noms: ["Agent"]) == "Exécuté 1 agent")
    #expect(ResumeOutils.resume(noms: ["ToolSearch", "SendMessage"]) == "Outils chargés, Message envoyé à l'agent")
    #expect(ResumeOutils.resume(noms: ["mcp__plan-progress__plan_progress", "mcp__plan-progress__x",
                                       "mcp__linkedin__note"]) == "Utilisé Plan progress 2 fois, Utilisé Linkedin")
    #expect(ResumeOutils.resume(noms: ["mcp__semantic-memory__hippo_cherche",
                                       "mcp__semantic-memory__memory_store"])
        == "A consulté la mémoire, a retenu 1 souvenir")
}

@Test func intituleEnCoursSelonLAppel() {
    #expect(ResumeOutils.intituleEnCours(nom: "Bash", entree: #"{"command":"ls","description":"Lance les tests"}"#)
        == "Lance les tests")
    #expect(ResumeOutils.intituleEnCours(nom: "Read", entree: "{}") == "Lecture")
    #expect(ResumeOutils.intituleEnCours(nom: "mcp__linkedin__note", entree: "{}") == "Utilisation de Linkedin: note")
    #expect(ResumeOutils.intituleEnCours(nom: "WebFetch", entree: "") == "Lecture du web")
    #expect(ResumeOutils.intituleEnCours(nom: "Foo", entree: "") == "En train d'utiliser Foo")
}

@Test func nomsDeServeurLisibles() {
    #expect(ResumeOutils.serveurLisible("plan-progress") == "Plan progress")
    #expect(ResumeOutils.serveurLisible("claude_ai_Gmail") == "Gmail")
    #expect(ResumeOutils.nomMcpLisible(service: "linkedin", outil: "linkedin note") == "Linkedin: note")
    #expect(ResumeOutils.nomMcpLisible(service: "plan-progress", outil: "plan progress") == "Plan progress")
}

private func fil(_ evts: [Evenement]) -> [EvenementDate] {
    evts.enumerated().map {
        EvenementDate(seq: $0.offset + 1, sessionId: "s", ts: "2026-11-01T00:00:00.000Z", evt: $0.element)
    }
}

@Test func blocsSeparentMessagesEtGroupesContigus() {
    let blocs = BlocsFil.depuis(StructureFil.structurer(fil([
        .message(texte: "Lance", uuid: nil, auteur: nil),
        .outil(id: "t1", nom: "Bash", resume: "ls", detail: #"{"command":"ls"}"#, agent: nil),
        .resultatOutil(outilId: "t1", extrait: "a b", erreur: false, agent: nil),
        .outil(id: "t2", nom: "Read", resume: "x", detail: "{}", agent: nil),
        .texte(texte: "Voilà.", agent: nil),
        .outil(id: "t3", nom: "Grep", resume: "y", detail: "{}", agent: nil),
    ])))
    #expect(blocs.count == 4)
    guard case .utilisateur(_, "Lance") = blocs[0] else { Issue.record("message utilisateur attendu"); return }
    guard case .actions(let groupe) = blocs[1] else { Issue.record("groupe attendu"); return }
    #expect(groupe.elements.count == 2 && groupe.resume == "Exécuté 1 commande, lu 1 fichier")
    #expect(groupe.enCours, "le premier outil a un résultat, le second non")
    guard case .assistant(_, "Voilà.") = blocs[2] else { Issue.record("réponse attendue"); return }
    guard case .actions(let dernier) = blocs[3] else { Issue.record("dernier groupe attendu"); return }
    #expect(dernier.enCours && dernier.echecs == 0)
}

@Test func tachesSuccessivesNeGardentQueLaDerniere() {
    let blocs = BlocsFil.depuis(StructureFil.structurer(fil([
        .taches([TacheFil(contenu: "a", etat: .attente)]),
        .texte(texte: "Je commence.", agent: nil),
        .taches([TacheFil(contenu: "a", etat: .fait)]),
    ])))
    #expect(blocs.count == 2)
    guard case .autre(.simple(let seq, _, .taches(let taches))) = blocs[0] else {
        Issue.record("tâches attendues")
        return
    }
    #expect(seq == 3 && taches == [TacheFil(contenu: "a", etat: .fait)], "la dernière prend la place de la première")
}

@Test func echecsCompteLesOutilsEnErreur() {
    let blocs = BlocsFil.depuis(StructureFil.structurer(fil([
        .outil(id: "t1", nom: "Bash", resume: "x", detail: "{}", agent: nil),
        .resultatOutil(outilId: "t1", extrait: "boum", erreur: true, agent: nil),
    ])))
    guard case .actions(let groupe) = blocs.first else { Issue.record("groupe attendu"); return }
    #expect(groupe.echecs == 1 && !groupe.enCours)
    #expect(groupe.resume == "Exécuté 1 commande")
}
