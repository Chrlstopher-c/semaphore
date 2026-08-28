import Foundation
import Testing

@testable import VigieNoyau

/// Charge utile calquée sur `versMissionApi` — tous les champs, y compris ceux
/// que le serveur rend nuls ou figés.
private let missionJson = """
{
  "blockedSince": null, "pausedAgo": null, "idleAgo": "12 min", "doneAgo": null,
  "id": "4f2a11bc", "title": "Corriger le relais de pièces jointes",
  "project": "ccremote", "worktree": "", "branch": "",
  "account": "perso", "machine": "trinityarch",
  "git": {"uncommitted": 3, "branch": "main", "lastCommit": "a1b2c3d", "at": 1755400000000},
  "state": "idle", "ctx": 41,
  "ctxDetail": [
    {"nom": "socle système", "tokens": 24000, "differe": false},
    {"nom": "outils MCP", "tokens": 36000, "differe": true}
  ],
  "ctxTokens": {"utilises": 79000, "max": 200000},
  "cost": 3.42, "team": "lead + 2 sous-agents", "model": "claude-opus-5",
  "epoch": 2, "retries": "1 / 3", "sessionId": "e7c1-88",
  "mandate": {"but": "Réparer le relais binaire", "critere": "Le PNG s'affiche dans le fil"},
  "inspection": {
    "lastVerdict": "boucle", "lastAt": 1755400500000,
    "motif": "trois relectures du même fichier sans écriture",
    "decision": "en_attente", "attendArbitrage": true,
    "libelle": "boucle — décision attendue"
  },
  "freshlyDispatched": false, "ultracode": false,
  "subagents": [
    {"id": "agent-1", "name": "Paragraphe sur la mer", "role": "Explore",
     "status": "termine", "action": "lu 12 fichiers", "feed": [], "feedUnavailable": false}
  ],
  "feed": [
    {"ts": "23:59:58", "at": 1755388798000, "type": "system", "text": "[harness] planifiee → en_cours"},
    {"ts": "23:59:58", "at": 1755388798000, "type": "activity", "text": "Je relis le relais", "nature": "reflexion"},
    {"ts": "23:59:58", "at": 1755388798000, "type": "activity", "text": "Read harness_proxy.py", "tool": "Read"},
    {"ts": "00:00:04", "at": 1755388804000, "type": "activity", "text": "Edit harness_proxy.py",
     "tool": "Edit", "result": "1 remplacement", "resultError": false}
  ],
  "landing": null,
  "partial": {"type": "reflexion", "contenu": "Je vérifie le type de contenu…"}
}
"""

@Suite("Mission")
struct MissionTests {
    private func decoder(_ texte: String) throws -> MissionApi {
        try JSONDecoder().decode(MissionApi.self, from: Data(texte.utf8))
    }

    @Test("le détail d'une mission se décode entièrement")
    func detail() throws {
        let mission = try decoder(missionJson)
        #expect(mission.state == .auRepos)
        #expect(mission.idleAgo == "12 min")
        #expect(mission.git?.uncommitted == 3)
        #expect(mission.ctxTokens.utilises == 79000)
        #expect(mission.ctxDetail.last?.differe == true)
        #expect(mission.inspection.attendArbitrage)
        #expect(mission.inspection.lastVerdict == .boucle)
        #expect(mission.subagents.first?.status == .termine)
        #expect(mission.partial?.type == .reflexion)
    }

    /// `git: null` veut dire JAMAIS MESURÉ, pas « propre ». C'est la distinction
    /// qui faisait passer une équipe au travail non commité pour une équipe qui
    /// a livré.
    @Test("git absent reste distinct de git propre")
    func gitJamaisMesure() throws {
        let texte = missionJson.replacingOccurrences(
            of: #""git": {"uncommitted": 3, "branch": "main", "lastCommit": "a1b2c3d", "at": 1755400000000}"#,
            with: #""git": null"#
        )
        #expect(try decoder(texte).git == nil)
    }

    /// Un état ajouté côté Pi ne doit pas vider le Parc.
    @Test("un état inconnu se conserve au lieu de faire échouer la ligne")
    func etatInconnu() throws {
        let texte = missionJson.replacingOccurrences(of: #""state": "idle""#, with: #""state": "atterrissage""#)
        let mission = try decoder(texte)
        #expect(mission.state.rawValue == "atterrissage")
        #expect(!mission.state.estVivante)
    }

    /// `☠` Sans clé synthétisée, SwiftUI recrée les vues à chaque sondage :
    /// blocs dépliés refermés, défilement rejeté, sélection annulée.
    @Test("le fil reçoit des clés stables malgré l'absence d'identifiant")
    func clesStables() throws {
        let mission = try decoder(missionJson)
        let indexes = FeedEventApi.indexer(mission.feed)
        #expect(indexes.count == 4)
        #expect(Set(indexes.map(\.id)).count == 4)
        // Trois lignes partagent la même milliseconde : seul le rang les sépare.
        #expect(indexes[0].id == "1755388798000|system|0")
        #expect(indexes[1].id == "1755388798000|activity|0")
        #expect(indexes[2].id == "1755388798000|activity|1")
    }

    @Test("les clés survivent au sondage suivant, qui rend le fil entier")
    func clesStablesEntreDeuxSondages() throws {
        let mission = try decoder(missionJson)
        let premier = FeedEventApi.indexer(mission.feed)
        var suivant = mission.feed
        suivant.append(
            FeedEventApi(
                ts: "00:00:09", at: 1755388809000, type: .systeme,
                text: "[sdk] running → idle", nature: nil, tool: nil, auto: nil,
                pending: nil, resolved: nil, path: nil, result: nil, resultError: nil
            )
        )
        let second = FeedEventApi.indexer(suivant)
        #expect(Array(second.prefix(4)).map(\.id) == premier.map(\.id))
    }

    /// `ts` est `HH:MM:SS` : de part et d'autre de minuit, l'écart calculé
    /// dessus est négatif de 24 h. `at` est la seule base juste.
    @Test("les durées se calculent sur at, jamais sur ts")
    func dureeSurAt() throws {
        let mission = try decoder(missionJson)
        let avantMinuit = mission.feed[0]
        let apresMinuit = mission.feed[3]
        #expect(avantMinuit.ts > apresMinuit.ts)
        #expect(DureeFil.entre(avantMinuit, apresMinuit) == 6000)
        let intervalles = DureeFil.intervalles(mission.feed)
        #expect(intervalles.count == 4)
        #expect(intervalles[2] == 6000)
        #expect(intervalles[3] == nil)
    }

    @Test("la liste du parc rend un fil vide et aucun partiel")
    func listeDuParc() throws {
        let corps = Data(
            """
            {"pcOnline": true, "stale": false, "data": [
              {"blockedSince": null, "pausedAgo": null, "idleAgo": null, "doneAgo": "3 h",
               "id": "aa", "title": "T", "project": "p", "worktree": "", "branch": "",
               "account": "perso", "machine": null, "git": null, "state": "terminee", "ctx": 0,
               "ctxDetail": [], "ctxTokens": {"utilises": null, "max": null}, "cost": 0,
               "team": "lead seul", "model": "(non résolu)", "epoch": 0, "retries": "0 / 3",
               "sessionId": null, "mandate": {"but": "", "critere": ""},
               "inspection": {"lastVerdict": null, "lastAt": null, "motif": null,
                              "decision": null, "attendArbitrage": false, "libelle": null},
               "freshlyDispatched": false, "ultracode": false, "subagents": [], "feed": [],
               "landing": null, "partial": null}
            ]}
            """.utf8
        )
        let lecture = DecodeurContrat.lecture([MissionApi].self, statut: 200, corps: corps)
        let missions = try #require(lecture.charge)
        #expect(missions.count == 1)
        #expect(missions[0].partial == nil)
        #expect(missions[0].feed.isEmpty)
        #expect(missions[0].inspection.lastVerdict == nil)
    }
}
