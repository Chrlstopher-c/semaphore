import Foundation
import Testing

@testable import VigieNoyau

@Suite("Fil orchestrateur")
struct FilTests {
    private func donnees(_ texte: String) -> Data { Data(texte.utf8) }

    @Test("la liste des fils porte sa fenêtre d'autonomie et son plafond")
    func listeDesFils() throws {
        let corps = donnees(
            """
            {"pcOnline": true, "stale": false, "data": [
              {"id": "af847b10", "titre": "Chantier Vigie", "creeA": 1755300000000,
               "majA": 1755400000000, "active": true, "contextPct": 37, "compactions": 2,
               "model": "claude-opus-5", "effort": "high", "machine": "trinityarch",
               "autonomieDebut": 1755380000000, "autonomieFin": 1755420000000,
               "autonomieObjectif": "avancer le noyau", "plafondAutonomie": "12"},
              {"id": "b1", "titre": "Fil neuf", "creeA": 1755400000000, "majA": 1755400000000,
               "active": false, "contextPct": null, "compactions": 0, "model": null,
               "effort": null, "machine": null, "autonomieDebut": null, "autonomieFin": null,
               "autonomieObjectif": null, "plafondAutonomie": "herite"}
            ]}
            """
        )
        let fils = try #require(DecodeurContrat.lecture([FilApi].self, statut: 200, corps: corps).charge)
        #expect(fils[0].plafondAutonomie == .valeur(12))
        #expect(fils[0].contextPct == 37)
        #expect(fils[1].plafondAutonomie == .herite)
        #expect(fils[1].model == nil)
    }

    /// `☠` La route du DÉTAIL ne sert ni `creeA`, ni `majA`, ni `machine` —
    /// contrairement à ce que l'interface TypeScript laisse croire par héritage.
    /// Les exiger ici ferait échouer le décodage de l'écran principal.
    @Test("le détail d'un fil décode sans creeA, majA ni machine")
    func detailSansMetadonnees() throws {
        let corps = donnees(
            """
            {"pcOnline": true, "stale": false, "data": {
              "id": "af847b10", "titre": "Chantier Vigie",
              "events": [
                {"seq": 41, "type": "operateur", "contenu": "lance l'équipe", "at": 1755400000000,
                 "model": null, "effort": null, "detail": null, "resultat": null,
                 "pieces": [{"nom": "capture.png", "type": "image/png", "taille": 20481,
                             "url": "/api/harness/orchestrator/conversations/af847b10/pieces/1.png"}]},
                {"seq": 42, "type": "mandat", "contenu": "p-88", "at": 1755400001000,
                 "model": "claude-opus-5", "effort": "high", "detail": null, "resultat": null,
                 "pieces": []},
                {"seq": 43, "type": "outil", "contenu": "Read", "at": 1755400002000,
                 "model": "claude-opus-5", "effort": "high", "detail": "{\\"path\\":\\"a.ts\\"}",
                 "resultat": null, "pieces": []}
              ],
              "cursor": 43, "generating": true, "active": true, "contextPct": 37,
              "compactions": 2, "model": "claude-opus-5", "effort": "high", "fastMode": null,
              "partial": {"type": "texte", "contenu": "Je regarde le rel"},
              "autonomieDebut": null, "autonomieFin": null, "autonomieObjectif": null,
              "plafondAutonomie": "illimite"}}
            """
        )
        let detail = try #require(DecodeurContrat.lecture(DetailFilApi.self, statut: 200, corps: corps).charge)
        #expect(detail.cursor == 43)
        #expect(detail.generating)
        #expect(detail.fastMode == nil)
        #expect(detail.plafondAutonomie == .illimite)
        #expect(detail.partial?.type == .texte)
        // Sur un `mandat`, le contenu est l'IDENTIFIANT de la proposition.
        #expect(detail.events[1].contenu == "p-88")
        #expect(detail.events[0].pieces.first?.taille == 20481)
        // Un outil sans résultat est un appel EN VOL, pas un appel qui a rendu du vide.
        #expect(detail.events[2].resultat == nil)
        #expect(detail.events[2].detail != nil)
    }

    @Test("le sondage d'évènements rend le curseur et le bloc en cours")
    func evenementsDepuisCurseur() throws {
        let corps = donnees(
            """
            {"pcOnline": true, "stale": false, "data": {
              "events": [], "cursor": 43, "generating": true, "active": true,
              "contextPct": 37, "compactions": 2,
              "partial": {"type": "reflexion", "contenu": "Je pèse les deux options"}}}
            """
        )
        let suite = try #require(DecodeurContrat.lecture(EvenementsFilApi.self, statut: 200, corps: corps).charge)
        #expect(suite.events.isEmpty)
        #expect(suite.partial?.contenu == "Je pèse les deux options")
    }

    /// Un type d'évènement inconnu ne doit pas faire disparaître la ligne : le
    /// front avait exactement ce défaut, et une notification agissait sur
    /// l'orchestrateur sans jamais apparaître à l'écran.
    @Test("un type d'évènement inconnu se conserve")
    func typeEvenementInconnu() throws {
        let corps = donnees(
            """
            {"seq": 9, "type": "arbitrage", "contenu": "…", "at": 1, "model": null,
             "effort": null, "detail": null, "resultat": null, "pieces": []}
            """
        )
        let evenement = try JSONDecoder().decode(EvenementApi.self, from: corps)
        #expect(evenement.type.rawValue == "arbitrage")
        #expect(evenement.id == 9)
    }

    @Test("les trois états du plafond d'autonomie restent distincts")
    func plafondTroisEtats() {
        #expect(ReglagePlafondApi(jeton: "herite") == .herite)
        #expect(ReglagePlafondApi(jeton: "") == .herite)
        #expect(ReglagePlafondApi(jeton: "illimite") == .illimite)
        #expect(ReglagePlafondApi(jeton: "40") == .valeur(40))
        #expect(ReglagePlafondApi(jeton: "n'importe quoi") == .illisible("n'importe quoi"))
        #expect(ReglagePlafondApi(jeton: "40").libelle == "40 équipes sans clic")
        #expect(ReglagePlafondApi(jeton: "1").libelle == "1 équipe sans clic")
    }

    @Test("les rappels d'un fil se décodent avec leur consigne entière")
    func rappels() throws {
        let corps = donnees(
            """
            {"pcOnline": false, "stale": true, "message": "PC absent", "data": [
              {"id": "r-1", "label": "veille sécu", "instruction": "Relis les CVE du jour et résume.",
               "state": "actif", "nextAt": 1755430000000, "everyMinutes": 1440, "fired": 3,
               "maxFires": null, "lastFiredAt": 1755343600000, "lastError": null}
            ]}
            """
        )
        let lecture = DecodeurContrat.lecture([RappelApi].self, statut: 200, corps: corps)
        let rappels = try #require(lecture.charge)
        #expect(!lecture.releveFrais)
        #expect(rappels[0].state == .actif)
        #expect(rappels[0].everyMinutes == 1440)
        #expect(rappels[0].instruction.hasPrefix("Relis"))
    }

    @Test("une écriture rend la forme nue, jamais une enveloppe")
    func ecritureNue() throws {
        let corps = donnees(#"{"ok":true,"effet":"message envoyé — la réponse arrive en streaming"}"#)
        let accuse = try DecodeurContrat.ecriture(statut: 200, corps: corps).get()
        #expect(accuse.ok)
        #expect(accuse.effet.hasPrefix("message envoyé"))
        #expect(accuse.missionId == nil)
    }

    /// `compacted: false` et `interrupted: false` ne sont PAS des erreurs : il
    /// n'y avait rien à compacter, le fil ne générait rien. Le motif doit être
    /// montré plutôt qu'un succès de façade.
    @Test("les non-gestes rendent ok:true avec leur motif")
    func nonGestes() throws {
        let compact = try DecodeurContrat.ecriture(
            statut: 200,
            corps: donnees(#"{"ok":true,"effet":"rien à compacter sur ce fil","compacted":false}"#)
        ).get()
        #expect(compact.ok)
        #expect(compact.compacted == false)

        let stop = try DecodeurContrat.ecriture(
            statut: 200,
            corps: donnees(#"{"ok":true,"effet":"ce fil ne générait rien","interrupted":false}"#)
        ).get()
        #expect(stop.interrupted == false)
    }

    @Test("la création d'un fil rend le fil complet dans l'accusé")
    func creationDeFil() throws {
        let corps = donnees(
            """
            {"ok": true, "effet": "conversation créée", "conversation": {
              "id": "c-9", "titre": "Nouveau fil", "creeA": 1755400000000, "majA": 1755400000000,
              "active": false, "contextPct": null, "compactions": 0, "model": null,
              "effort": null, "machine": null, "autonomieDebut": null, "autonomieFin": null,
              "autonomieObjectif": null, "plafondAutonomie": "herite"}}
            """
        )
        let accuse = try DecodeurContrat.ecriture(statut: 200, corps: corps).get()
        #expect(accuse.conversation?.id == "c-9")
        #expect(accuse.conversation?.plafondAutonomie == .herite)
    }
}
