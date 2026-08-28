import Foundation
import Testing

@testable import VigieNoyau

@Suite("Parc, comptes et poste de travail")
struct ParcTests {
    private func donnees(_ texte: String) -> Data { Data(texte.utf8) }

    @Test("les deux fenêtres de quota se lisent en pourcentage")
    func comptes() throws {
        let corps = donnees(
            """
            {"pcOnline": true, "stale": false, "data": [
              {"id": "perso", "label": "Chris", "email": "chris@example.org",
               "status": "rejected", "isUsingOverage": true, "plan": "Claude Pro",
               "five_hour": {"util": 100, "resetLabel": "3 h 12", "resetAt": "10:30 PM"},
               "seven_day": {"util": 62, "resetLabel": "2 j 4 h",
                             "resetAt": "lundi 28 juil. · 08:00 AM"}},
              {"id": "pro", "label": "pro", "email": "", "status": "allowed",
               "isUsingOverage": false, "plan": "",
               "five_hour": {"util": 0, "resetLabel": "—", "resetAt": null},
               "seven_day": {"util": 0, "resetLabel": "—", "resetAt": null}}
            ]}
            """
        )
        let comptes = try #require(DecodeurContrat.lecture([AccountApi].self, statut: 200, corps: corps).charge)
        // `rejected` NE COUPE PAS : la session continue en dépassement payant.
        #expect(comptes[0].status == .rejete)
        #expect(comptes[0].isUsingOverage)
        #expect(comptes[0].fiveHour.util == 100)
        #expect(comptes[0].sevenDay.resetAt?.contains("lundi") == true)
        // Vide tant qu'aucune sonde n'a répondu — jamais un « Max » inventé.
        #expect(comptes[1].plan.isEmpty)
        #expect(comptes[1].fiveHour.resetAt == nil)
    }

    /// `metriques: null` signifie « pas pu mesurer », JAMAIS « tout à zéro », et
    /// une machine éteinte garde sa ligne.
    @Test("une machine hors ligne reste dans la liste, sans relevé")
    func metriquesMachines() throws {
        let corps = donnees(
            """
            {"pcOnline": true, "stale": false, "data": [
              {"id": "trinityarch", "enLigne": true, "metriques": {
                 "machine": "trinityarch", "cpuPct": 18, "memUtiliseeMo": 5120,
                 "memTotaleMo": 7580, "memPct": 67, "disqueUtiliseGo": 412.6,
                 "disqueTotalGo": 930.1, "tempCpuC": 72, "uptimeS": 91234,
                 "reseauMontantKo": 12.4, "reseauDescendantKo": 301.9,
                 "gpu": {"utilPct": 3, "memUtiliseeMo": 512, "memTotaleMo": 8192, "tempC": 41},
                 "releveA": 1755400000000}},
              {"id": "vps", "enLigne": false, "metriques": null}
            ]}
            """
        )
        let liste = try #require(DecodeurContrat.lecture([MetriquesMachineApi].self, statut: 200, corps: corps).charge)
        #expect(liste[0].metriques?.tempCpuC == 72)
        #expect(liste[0].metriques?.gpu?.utilPct == 3)
        #expect(liste[1].enLigne == false)
        #expect(liste[1].metriques == nil)
    }

    @Test("une machine sans GPU ni capteur rend des champs nuls, pas des zéros")
    func metriquesPartielles() throws {
        let corps = donnees(
            """
            {"machine": "vps", "cpuPct": null, "memUtiliseeMo": 900, "memTotaleMo": 2048,
             "memPct": 44, "disqueUtiliseGo": 12.0, "disqueTotalGo": 40.0, "tempCpuC": null,
             "uptimeS": 500, "reseauMontantKo": null, "reseauDescendantKo": null,
             "gpu": null, "releveA": 1755400000000}
            """
        )
        let releve = try JSONDecoder().decode(MetriquesHote.self, from: corps)
        #expect(releve.cpuPct == nil)
        #expect(releve.tempCpuC == nil)
        #expect(releve.gpu == nil)
    }

    @Test("le catalogue de modèles porte les efforts réellement acceptés")
    func modeles() throws {
        let corps = donnees(
            """
            {"pcOnline": true, "stale": false, "data": [
              {"id": "claude-opus-5", "label": "Opus 5", "alias": "opus", "enabled": true,
               "effort": ["low", "medium", "high", "xhigh"], "effortDefaut": "high",
               "fastMode": true, "ultracode": true, "note": "Le plus capable."},
              {"id": "claude-haiku-5", "label": "Haiku 5", "alias": null, "enabled": true,
               "effort": [], "effortDefaut": null, "fastMode": false, "ultracode": false,
               "note": "N'accepte aucun niveau d'effort."}
            ]}
            """
        )
        let modeles = try #require(DecodeurContrat.lecture([ModeleApi].self, statut: 200, corps: corps).charge)
        #expect(modeles[0].ultracode)
        // `effort` vide = le modèle REFUSE le paramètre : le sélecteur doit se griser.
        #expect(modeles[1].effort.isEmpty)
        #expect(modeles[1].effortDefaut == nil)
    }

    /// `☠` Troisième forme d'absence du PC, distincte de l'enveloppe H-75 :
    /// HTTP 200, `pc_online: false`, `status: "error"`.
    @Test("le poste éteint répond 200 avec pc_online faux")
    func postePcAbsent() {
        let corps = donnees(#"{"pc_online": false, "status": "error", "message": "PC unreachable"}"#)
        let lecture = DecodeurContrat.poste(StatutPosteApi.self, statut: 200, corps: corps)
        guard case .pcAbsent(let message) = lecture else {
            Issue.record("attendu .pcAbsent, obtenu \(lecture)")
            return
        }
        #expect(message == "PC unreachable")
    }

    @Test("un refus du poste n'est pas une absence")
    func posteRefus() {
        let corps = donnees(#"{"pc_online": true, "status": "error", "message": "session not found"}"#)
        let lecture = DecodeurContrat.poste(OrdrePosteApi.self, statut: 200, corps: corps)
        guard case .refus(let message) = lecture else {
            Issue.record("attendu .refus, obtenu \(lecture)")
            return
        }
        #expect(message == "session not found")
    }

    @Test("les sessions tmux portent un horodatage en SECONDES")
    func sessions() throws {
        let corps = donnees(
            """
            {"pc_online": true, "status": "ok", "sessions": [
              {"name": "claude", "created": 1755400000, "attached": true},
              {"name": "vigie", "created": 1755399000, "attached": false}
            ]}
            """
        )
        let lecture = DecodeurContrat.poste(SessionsPosteApi.self, statut: 200, corps: corps)
        guard case .fraiche(let charge) = lecture else {
            Issue.record("attendu .fraiche, obtenu \(lecture)")
            return
        }
        let sessions = try #require(charge.sessions)
        #expect(sessions.count == 2)
        // Secondes, pas millisecondes : tout le reste du contrat est en ms.
        #expect(sessions[0].created == 1_755_400_000)
        #expect(sessions[0].attached)
    }

    @Test("la configuration de pi-web se décode en camel")
    func configuration() throws {
        let corps = donnees(
            #"{"pc_host":"10.0.0.3","pc_mac":"aa:bb:cc:dd:ee:ff","#
                + #""default_model":"gpt-oss-120b","models":["gpt-oss-120b"]}"#
        )
        let config = try DecodeurContrat.nu(ConfigApi.self, statut: 200, corps: corps).get()
        #expect(config.pcHost == "10.0.0.3")
        #expect(config.defaultModel == "gpt-oss-120b")
    }

    @Test("les comptes Claude du poste n'ont rien à voir avec les quotas du harness")
    func comptesClaudeDuPoste() throws {
        let corps = donnees(
            #"{"pc_online": true, "status": "ok", "accounts": [{"id":"perso","label":"Perso","active":true}]}"#
        )
        let lecture = DecodeurContrat.poste(ComptesClaudeApi.self, statut: 200, corps: corps)
        guard case .fraiche(let charge) = lecture else {
            Issue.record("attendu .fraiche, obtenu \(lecture)")
            return
        }
        #expect(charge.accounts?.first?.active == true)
    }
}
