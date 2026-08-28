import Foundation
import Testing

@testable import VigieNoyau

@Suite("Notifications et déduplication")
struct NotificationTests {
    private func donnees(_ texte: String) -> Data { Data(texte.utf8) }

    /// Une ligne de notification, écrite en JSON plutôt que construite : c'est
    /// le décodage qu'on teste, pas un initialiseur qui n'existe pas en prod.
    private func ligne(_ id: String, _ createdAt: Int, lue: Bool = false) -> String {
        """
        {"id": "\(id)", "type": "equipe_terminee", "title": "Équipe terminée",
         "body": "ccremote — le relais est réparé", "missionId": "4f2a11bc",
         "conversationId": "af847b10", "createdAt": \(createdAt), "read": \(lue),
         "delivered": false, "deliveryError": null}
        """
    }

    private func lot(_ lignes: [String], unread: Int? = nil) throws -> ListeNotificationsApi {
        let corps = donnees(
            #"{"notifications": [\#(lignes.joined(separator: ","))], "unread": \#(unread ?? lignes.count)}"#
        )
        return try JSONDecoder().decode(ListeNotificationsApi.self, from: corps)
    }

    @Test("la liste et son compteur se décodent séparément")
    func decodage() throws {
        let corps = donnees(
            """
            {"pcOnline": true, "stale": false, "data": {
              "notifications": [
                {"id": "6f1b-a", "type": "equipe_echouee", "title": "Équipe en échec",
                 "body": "ccremote — worker disparu", "missionId": "4f2a11bc",
                 "conversationId": null, "createdAt": 1755400000000, "read": false,
                 "delivered": true, "deliveryError": null},
                {"id": "6f1b-b", "type": "type_inedit", "title": "Fait inconnu",
                 "body": "…", "missionId": null, "conversationId": "af847b10",
                 "createdAt": 1755400500000, "read": true, "delivered": false,
                 "deliveryError": "fenêtre d'autonomie fermée"}
              ], "unread": 7}}
            """
        )
        let liste = try #require(DecodeurContrat.lecture(ListeNotificationsApi.self, statut: 200, corps: corps).charge)
        // `☠` Le badge se lit sur `unread`, jamais sur le nombre de lignes : la
        // liste est plafonnée côté serveur et mentirait au-delà.
        #expect(liste.unread == 7)
        #expect(liste.notifications.count == 2)
        #expect(liste.notifications[0].type == .equipeEchouee)
        // `read` et `delivered` sont deux faits indépendants, jamais fondus.
        #expect(!liste.notifications[0].read && liste.notifications[0].delivered)
        #expect(liste.notifications[1].read && !liste.notifications[1].delivered)
        // Un type inédit s'affiche au lieu de faire échouer la ligne.
        #expect(liste.notifications[1].type.rawValue == "type_inedit")
        #expect(liste.notifications[1].deliveryError != nil)
    }

    /// À la première ouverture, la fenêtre serveur contient jusqu'à 50 faits
    /// vieux de plusieurs jours. Les sonner d'un coup ferait couper les
    /// notifications en une soirée.
    @Test("le premier relevé amorce sans rien signaler")
    func premierReleveSilencieux() throws {
        var filigrane = FiligraneNotifications()
        let releve = filigrane.retenir(try lot([ligne("a", 1000), ligne("b", 2000)]))
        #expect(releve.nouvelles.isEmpty)
        #expect(filigrane.amorce)
        #expect(filigrane.filigrane == 2000)
        #expect(filigrane.dejaVue("a"))
    }

    @Test("seuls les faits jamais vus ressortent, dans l'ordre chronologique")
    func nouvellesSeulement() throws {
        var filigrane = FiligraneNotifications()
        _ = filigrane.retenir(try lot([ligne("a", 1000)]))
        let releve = filigrane.retenir(try lot([ligne("c", 3000), ligne("a", 1000), ligne("b", 2000)]))
        #expect(releve.nouvelles.map(\.id) == ["b", "c"])
        #expect(!releve.rattrapageIncomplet)
    }

    /// `☠` Le cœur du piège : un UUID v4 n'est pas ordonné. Deux faits nés dans
    /// la MÊME milliseconde, dont l'un déjà vu, doivent se départager par
    /// l'identifiant — un filigrane temporel seul en perdrait un.
    @Test("deux faits de la même milliseconde se départagent par l'identifiant")
    func memeMilliseconde() throws {
        var filigrane = FiligraneNotifications()
        _ = filigrane.retenir(try lot([ligne("9c3f", 5000)]))
        let releve = filigrane.retenir(try lot([ligne("9c3f", 5000), ligne("1a02", 5000)]))
        #expect(releve.nouvelles.map(\.id) == ["1a02"])
    }

    @Test("un fait déjà signalé ne ressort pas parce qu'il a été lu")
    func changementDEtatNestPasUnFait() throws {
        var filigrane = FiligraneNotifications()
        _ = filigrane.retenir(try lot([ligne("a", 1000)]))
        _ = filigrane.retenir(try lot([ligne("b", 2000)]))
        let releve = filigrane.retenir(try lot([ligne("a", 1000, lue: true), ligne("b", 2000, lue: true)]))
        #expect(releve.nouvelles.isEmpty)
    }

    /// La route est plafonnée à 50 SANS curseur `since` : deux jours sans ouvrir
    /// Vigie et les plus anciennes ont quitté la fenêtre. Le dire est le seul
    /// moyen de ne pas croire à un parc silencieux.
    @Test("un lot plein qui démarre après le filigrane dénonce le trou")
    func rattrapageIncomplet() throws {
        var filigrane = FiligraneNotifications()
        _ = filigrane.retenir(try lot([ligne("vieux", 1000)]))
        let plein = (0..<ListeNotificationsApi.plafondServeur).map { ligne("n\($0)", 100_000 + $0) }
        let releve = filigrane.retenir(try lot(plein, unread: 50))
        #expect(releve.rattrapageIncomplet)
        #expect(releve.nouvelles.count == 50)
    }

    @Test("un lot non plein ne dénonce aucun trou")
    func lotPartielSansTrou() throws {
        var filigrane = FiligraneNotifications()
        _ = filigrane.retenir(try lot([ligne("vieux", 1000)]))
        let releve = filigrane.retenir(try lot([ligne("neuf", 100_000)]))
        #expect(!releve.rattrapageIncomplet)
    }

    @Test("la mémoire des identifiants reste bornée")
    func memoireBornee() throws {
        var filigrane = FiligraneNotifications()
        _ = filigrane.retenir(try lot([ligne("amorce", 1)]))
        for tranche in 0..<12 {
            let lignes = (0..<50).map { ligne("t\(tranche)-\($0)", 1_000_000 + tranche * 50 + $0) }
            _ = filigrane.retenir(try lot(lignes))
        }
        #expect(filigrane.taille <= FiligraneNotifications.plafondIdentifiants)
        // L'amorce, la plus ancienne, est la première oubliée.
        #expect(!filigrane.dejaVue("amorce"))
    }

    @Test("le filigrane se persiste et se relit sans perdre sa mémoire")
    func persistance() throws {
        var filigrane = FiligraneNotifications()
        _ = filigrane.retenir(try lot([ligne("a", 1000)]))
        let brut = try JSONEncoder().encode(filigrane)
        var relu = try JSONDecoder().decode(FiligraneNotifications.self, from: brut)
        #expect(relu == filigrane)
        #expect(relu.retenir(try lot([ligne("a", 1000)])).nouvelles.isEmpty)
    }
}
