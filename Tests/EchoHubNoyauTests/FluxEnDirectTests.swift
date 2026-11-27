import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Flux en direct : événements et silence")
struct FluxEnDirectTests {
    private func lire(_ donnees: String) -> EvenementFlux? {
        LectureEvenement.lire(TrameSSE(evenement: nil, donnees: donnees))
    }

    @Test func activiteDeLAgent() {
        let evenement = lire(#"{"type":"activite","activite":{"phase":"outil","tokens":412,"tokens_par_seconde":25.4,"outil":{"nom":"ecrire_fichier","chemin":"src/app.py","caracteres":1800,"fichiers_sauves":[],"parametres":{"chemin":"src/app.py"}},"taches":[{"titre":"Écrire l'API","etat":"in_progress"}],"contexte":{"tokens":30000,"total":100352},"lecture":null,"compaction":null,"debut":"2026-11-28T10:00:00Z"}}"#)
        guard case .activite(let activite)? = evenement else { Issue.record("pas une activité"); return }
        #expect(activite.phase == "outil")
        #expect(activite.outil?.chemin == "src/app.py")
        #expect(activite.taches?.first?.etat == "in_progress")
        #expect(activite.contexte?.total == 100352)
        #expect(activite.debut != nil)
    }

    @Test func activiteMinimaleDUnBackendAnterieur() {
        guard case .activite(let a)? = lire(#"{"type":"activite","activite":{"phase":"texte","tokens":3,"tokens_par_seconde":0}}"#)
        else { Issue.record("pas une activité"); return }
        #expect(a.outil == nil && a.taches == nil && a.debut == nil)
    }

    @Test func commandeEtSortieShell() {
        guard case .commande(let c)? = lire(#"{"type":"commande","commande":{"id":"c1","nom":"compact","etat":"en_cours","etape":"resume","etapes":[],"detail":"Résumé","resumeur":null,"tokens":null,"tokens_par_seconde":null,"moteur":null,"debut":"2026-11-28T10:00:00Z","duree_ms":1200,"erreur":null}}"#)
        else { Issue.record("pas une commande"); return }
        #expect(c.nom == "compact" && c.dureeMs == 1200)
        guard case .commandeShell(let s)? = lire(#"{"type":"commande_shell","commande_id":"k1","appel_id":"a1","etat":"en_cours","sortie":"ok\n","code":null}"#)
        else { Issue.record("pas une sortie shell"); return }
        #expect(s.sortie == "ok\n" && s.code == nil)
    }

    @Test func seuilsDeSilence() {
        let t0 = Date(timeIntervalSince1970: 0)
        #expect(!RegleSilence.muet(depuis: t0, octetsRecus: true, maintenant: t0.addingTimeInterval(19)))
        #expect(RegleSilence.muet(depuis: t0, octetsRecus: true, maintenant: t0.addingTimeInterval(20)))
        #expect(!RegleSilence.muet(depuis: t0, octetsRecus: false, maintenant: t0.addingTimeInterval(119)))
        #expect(RegleSilence.muet(depuis: t0, octetsRecus: false, maintenant: t0.addingTimeInterval(120)))
    }

    @Test func attenteApresEchecDoubleEtPlafonne() {
        #expect([1, 2, 3, 4, 5, 9].map(RegleSilence.delaiApresEchec) == [1, 2, 4, 8, 10, 10])
    }

    @Test func seuleLaCoupureDeTransportSeRaccroche() {
        let coupure = EvenementFlux.erreur(EvenementErreur(code: "transport", message: "m", remediation: nil))
        let serveur = EvenementFlux.erreur(EvenementErreur(code: "modele_absent", message: "m", remediation: nil))
        #expect(coupure.estCoupureTransport && !serveur.estCoupureTransport)
    }
}
