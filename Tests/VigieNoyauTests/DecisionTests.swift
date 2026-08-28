import Foundation
import Testing

@testable import VigieNoyau

@Suite("Décisions — mandats, rallonges, inspection")
struct DecisionTests {
    private func donnees(_ texte: String) -> Data { Data(texte.utf8) }

    /// `☠` Cette route ne passe par AUCUNE vue de traduction : elle rend l'objet
    /// du domaine tel quel. Les noms de champs sont donc français et les dates
    /// s'appellent `creeA` / `majA`, pas `createdAt`.
    @Test("les propositions sont servies BRUTES, avec le vocabulaire du domaine")
    func propositionsBrutes() throws {
        let corps = donnees(
            """
            {"pcOnline": true, "stale": false, "data": [
              {"id": "p-88", "conversationId": "af847b10", "projet": "ccremote",
               "objectif": "Réparer le relais de pièces jointes",
               "critereArret": "Un PNG s'affiche dans le fil", "perimetre": "pi-web/ uniquement",
               "acces": "ecriture", "budgetMaxUsd": 12, "modele": null, "effort": null,
               "statut": "en_attente", "missionId": null, "detail": null,
               "creeA": 1755400000000, "majA": 1755400000000}
            ]}
            """
        )
        let liste = try #require(DecodeurContrat.lecture([PropositionApi].self, statut: 200, corps: corps).charge)
        let mandat = try #require(liste.first)
        #expect(mandat.acces == .ecriture)
        #expect(mandat.acces.ouvreLEcriture)
        #expect(mandat.budgetMaxUsd == 12)
        #expect(mandat.statut == .enAttente)
        #expect(mandat.modele == nil)
        #expect(mandat.creeA == 1_755_400_000_000)
    }

    /// H-61 : le droit RÉEL doit être lisible. Un accès absent ou inconnu ne
    /// doit jamais se lire « écriture ».
    @Test("un accès inconnu n'ouvre pas l'écriture")
    func accesInconnu() {
        #expect(!AccesMandatApi(rawValue: "lecture").ouvreLEcriture)
        #expect(!AccesMandatApi(rawValue: "read-only").ouvreLEcriture)
        #expect(AccesMandatApi(rawValue: "ecriture").ouvreLEcriture)
    }

    @Test("l'approbation d'un mandat rend l'équipe créée")
    func approbation() throws {
        let corps = donnees(
            #"{"ok":true,"effet":"équipe lancée sur ccremote","missionId":"4f2a11bc"}"#
        )
        let accuse = try DecodeurContrat.ecriture(statut: 200, corps: corps).get()
        #expect(accuse.missionId == "4f2a11bc")
    }

    /// Migration 29 : les deux volets sont INDÉPENDANTS. Une demande de plage ne
    /// porte aucun plafond, et `null` ne veut pas dire « remets le défaut ».
    @Test("une rallonge peut ne porter que la fenêtre")
    func rallongeFenetreSeule() throws {
        let corps = donnees(
            """
            {"pcOnline": true, "stale": false, "data": [
              {"id": "d-1", "conversationId": "af847b10", "plafondDemande": null,
               "fenetreDebut": 1755400000000, "fenetreFin": 1755440000000,
               "fenetreObjectif": "finir le noyau", "motif": "chantier long, nuit calme",
               "statut": "en_attente", "detail": null, "creeA": 1755399000000}
            ]}
            """
        )
        let liste = try #require(DecodeurContrat.lecture([RallongeApi].self, statut: 200, corps: corps).charge)
        let demande = try #require(liste.first)
        #expect(demande.plafondDemande == nil)
        #expect(!demande.porteUnPlafond)
        #expect(demande.porteUneFenetre)
        #expect(demande.statut == .enAttente)
    }

    @Test("une rallonge peut ne porter que le plafond")
    func rallongePlafondSeul() throws {
        let corps = donnees(
            """
            {"pcOnline": true, "stale": false, "data": [
              {"id": "d-2", "conversationId": "af847b10", "plafondDemande": "illimite",
               "fenetreDebut": null, "fenetreFin": null, "fenetreObjectif": null,
               "motif": "20 équipes prévues", "statut": "en_attente", "detail": null,
               "creeA": 1755399000000}
            ]}
            """
        )
        let liste = try #require(DecodeurContrat.lecture([RallongeApi].self, statut: 200, corps: corps).charge)
        let demande = try #require(liste.first)
        #expect(demande.plafondDemande == .illimite)
        #expect(!demande.porteUneFenetre)
    }

    /// La lecture et l'écriture partagent UNE seule forme d'inspection : elles
    /// ont déjà divergé (`verdict` contre `lastVerdict`) et l'écran affichait
    /// « undefined ».
    @Test("l'inspection a la même forme en lecture et en écriture")
    func inspectionMemeForme() throws {
        let corps = donnees(
            """
            {"ok": true, "effet": "verdict : boucle", "inspection": {
              "lastVerdict": "boucle", "lastAt": 1755400500000,
              "motif": "trois relectures sans écriture", "decision": "en_attente",
              "attendArbitrage": true, "libelle": "boucle — décision attendue"}}
            """
        )
        let accuse = try DecodeurContrat.ecriture(statut: 200, corps: corps).get()
        let inspection = try #require(accuse.inspection)
        #expect(inspection.lastVerdict == .boucle)
        #expect(inspection.decision == .enAttente)
        #expect(inspection.attendArbitrage)
    }

    @Test("les routes portent les identifiants encodés")
    func routes() {
        #expect(Route.approuverMandat("p-88") == "/api/harness/orchestrator/propositions/p-88/approve")
        #expect(Route.evenementsFil("af847b10", depuis: 43)
            == "/api/harness/orchestrator/conversations/af847b10/events?since=43")
        #expect(Route.sante == "/api/harness/health")
        // Un titre à espaces ou un nom de fichier accentué doit rester routable.
        #expect(Route.pieceJointe(fil: "c 9", fichier: "café.png")
            == "/api/harness/orchestrator/conversations/c%209/pieces/caf%C3%A9.png")
    }
}
