import Foundation
import Testing

@testable import VigieNoyau

/// Les formes d'échec, et surtout les quatre 409 de `/propositions/{id}/approve`.
/// Les messages sont recopiés de `dispatch-mandat.ts` et `serveur-api.ts`, y
/// compris leur mélange d'apostrophes droites et typographiques.
@Suite("Erreurs du contrat")
struct ErreurTests {
    private func donnees(_ texte: String) -> Data { Data(texte.utf8) }

    @Test("502 du relais : le harness est mort sur le Pi, pas le PC")
    func harnessInjoignable() {
        let corps = donnees(
            #"{"error":"harness_injoignable","message":"Le control plane du harness "#
                + #"ne répond pas sur le Pi — ce n'est pas un PC éteint."}"#
        )
        let lecture = DecodeurContrat.lecture([MachineApi].self, statut: 502, corps: corps)
        let erreur = lecture.erreur
        #expect(erreur?.genre == .harnessInjoignable)
        #expect(erreur?.message.contains("pas un PC éteint") == true)
    }

    @Test("404 : le message serveur passe tel quel")
    func introuvable() {
        let corps = donnees(#"{"error":"mission introuvable"}"#)
        let lecture = DecodeurContrat.lecture(MissionApi.self, statut: 404, corps: corps)
        #expect(lecture.erreur?.genre == .introuvable)
        #expect(lecture.erreur?.message == "mission introuvable")
    }

    @Test("501 : le geste n'est pas câblé, il doit disparaître de l'écran")
    func nonCable() {
        let corps = donnees(#"{"error":"inspection non câblée sur ce déploiement"}"#)
        let resultat = DecodeurContrat.ecriture(statut: 501, corps: corps)
        guard case .failure(let erreur) = resultat else {
            Issue.record("attendu un échec")
            return
        }
        #expect(erreur.genre == .nonCable)
        #expect(erreur.message == "inspection non câblée sur ce déploiement")
    }

    @Test("400 : le texte nomme ce qui a été refusé")
    func requeteInvalide() {
        let corps = donnees(#"{"error":"machine « vps » inconnue — machines disponibles : trinityarch"}"#)
        let resultat = DecodeurContrat.ecriture(statut: 400, corps: corps)
        guard case .failure(let erreur) = resultat else {
            Issue.record("attendu un échec")
            return
        }
        #expect(erreur.genre == .requeteInvalide)
    }

    @Test("401 : session périmée, il faut ressaisir le mot de passe")
    func authentification() {
        let lecture = DecodeurContrat.lecture(MissionApi.self, statut: 401, corps: Data())
        #expect(lecture.erreur?.genre == .authentification)
    }

    @Test("conflit 1/4 — projet non-git déjà occupé (H-56)")
    func conflitProjetOccupe() {
        let message =
            "ccremote n'est pas un dépôt git : une seule équipe à la fois, faute d'isolation possible "
            + "(git worktree indisponible). Équipe déjà active : mission 4f2a11bc, état en_cours — "
            + "termine-la avec arreter_equipe avant d’en lancer une autre (H-56, projets non-git)."
        #expect(ClassementErreur.conflit(message) == .projetOccupe)
    }

    @Test("conflit 2/4 — mandat tranché entre l'affichage et le clic")
    func conflitMandatDejaTranche() {
        let message = "ce mandat a déjà été autorisé — l’équipe est lancée, elle est visible dans le Parc"
        #expect(ClassementErreur.conflit(message) == .mandatDejaTranche)
    }

    @Test("conflit 3/4 — projet absent de la machine du fil")
    func conflitProjetAbsent() {
        let message =
            "le projet « stockiop » n'est pas exploitable sur la machine « vps » "
            + "(cherché : /srv/stockiop) — choisir une autre machine pour ce fil, "
            + "ou un projet présent sur celle-ci"
        #expect(ClassementErreur.conflit(message) == .projetAbsentDeLaMachine)
    }

    @Test("conflit 4/4 — machine hors ligne")
    func conflitRoutageMachine() {
        let message = "mandat p-1 : la machine « vps » est hors ligne. En ligne actuellement : trinityarch"
        #expect(ClassementErreur.conflit(message) == .routageMachine)
    }

    @Test("les autres 409 gardent leur cas propre")
    func autresConflits() {
        #expect(ClassementErreur.conflit("demande de rallonge déjà tranchée ou inconnue") == .rallongeDejaTranchee)
        #expect(
            ClassementErreur.conflit("rappel introuvable dans ce fil, ou état incompatible avec « pause »")
                == .rappelIncompatible
        )
        #expect(ClassementErreur.conflit("mandat déjà tranché ou inconnu") == .mandatDejaTranche)
    }

    @Test("un 409 traverse le décodeur d'écriture avec son cas métier")
    func conflitDeboutEnBout() {
        let corps = donnees(#"{"error":"ce mandat a déjà été refusee — il n’y a plus rien à décider dessus"}"#)
        let resultat = DecodeurContrat.ecriture(statut: 409, corps: corps)
        guard case .failure(let erreur) = resultat else {
            Issue.record("attendu un échec")
            return
        }
        #expect(erreur.genre == .conflit(.mandatDejaTranche))
        #expect(erreur.statut == 409)
    }

    @Test("un corps vide ne masque pas le code HTTP")
    func corpsVide() {
        let erreur = ClassementErreur.classer(statut: 500, corps: Data())
        #expect(erreur.genre == .interne)
        #expect(erreur.message == "HTTP 500")
    }
}
