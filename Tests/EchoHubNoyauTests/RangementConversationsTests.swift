import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Rangement des conversations")
struct RangementConversationsTests {
    private let calendrier: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris")!
        return c
    }()
    private let maintenant = ISO8601DateFormatter().date(from: "2026-11-28T15:00:00Z")!

    private func conv(_ id: String, ilYa heures: Double, projet: String? = nil, titre: String = "x") -> ResumeConversation {
        ResumeConversation(id: id, titre: titre, majLe: maintenant.addingTimeInterval(-heures * 3600), projet: projet)
    }

    @Test func projetsDAbordPuisPeriodesDansLOrdre() {
        let r = RangementConversations([
            conv("a", ilYa: 1, projet: "site"), conv("b", ilYa: 2), conv("c", ilYa: 20),
            conv("d", ilYa: 60, projet: "jeu"), conv("e", ilYa: 24 * 30), conv("f", ilYa: 24 * 4, projet: "site"),
        ], maintenant: maintenant, calendrier: calendrier)
        #expect(r.projets.map(\.libelle) == ["site", "jeu"])
        #expect(r.projets[0].conversations.map(\.id) == ["a", "f"])
        #expect(r.periodes.map(\.libelle) == ["Aujourd'hui", "Hier", "Plus ancien"])
        #expect(r.periodes[1].conversations.map(\.id) == ["c"])
    }

    @Test func semaineEntreHierEtPlusAncien() {
        let r = RangementConversations([conv("s", ilYa: 24 * 3)], maintenant: maintenant, calendrier: calendrier)
        #expect(r.periodes.map(\.libelle) == ["Cette semaine"])
    }

    @Test func filtreSansCasseNiAccentsSurTitreEtProjet() {
        let liste = [conv("a", ilYa: 1, titre: "Écran de démarrage"), conv("b", ilYa: 1, projet: "Sémaphore"),
                     conv("c", ilYa: 1, titre: "autre")]
        #expect(RangementConversations.filtrer(liste, "ecran").map(\.id) == ["a"])
        #expect(RangementConversations.filtrer(liste, "SEMA").map(\.id) == ["b"])
        #expect(RangementConversations.filtrer(liste, "  ").count == 3)
    }

    @Test func projetDecodeOuAbsent() throws {
        let json = #"[{"id":"1","titre":"t","cree_le":"2026-11-28T10:00:00Z","maj_le":"2026-11-28T10:00:00Z","archivee":false,"nb_messages":0,"projet":"site"},{"id":"2","titre":"t","cree_le":"2026-11-28T10:00:00Z","maj_le":"2026-11-28T10:00:00Z","archivee":false,"nb_messages":0}]"#
        let liste = try CodageJSON.decodeur().decode([ResumeConversation].self, from: Data(json.utf8))
        #expect(liste.map(\.projet) == ["site", nil])
    }
}
