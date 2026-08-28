import Foundation
import Testing

@testable import VigieNoyau

/// Les trois régimes de H-75, plus la forme nue. Chaque charge utile est copiée
/// sur ce que le control plane sérialise réellement (`api-web/enveloppe.ts`).
@Suite("Enveloppe H-75")
struct EnveloppeTests {
    private func donnees(_ texte: String) -> Data { Data(texte.utf8) }

    @Test("PC en ligne : données fraîches")
    func pcEnLigne() throws {
        let corps = donnees(#"{"pcOnline":true,"stale":false,"data":[{"id":"tour","enLigne":true,"supersedes":0}]}"#)
        let lecture = DecodeurContrat.lecture([MachineApi].self, statut: 200, corps: corps)
        let machines = try #require(lecture.charge)
        #expect(lecture.releveFrais)
        #expect(machines.first?.id == "tour")
        #expect(lecture.erreur == nil)
    }

    /// Le cas le plus important du produit : la nuit, ceci est le régime NOMINAL.
    @Test("PC absent avec données connues : ce n'est pas une erreur")
    func pcAbsentAvecDonnees() throws {
        let corps = donnees(
            #"{"pcOnline":false,"stale":true,"data":[],"#
                + #""message":"PC absent — dernières données connues, pas d'erreur."}"#
        )
        let lecture = DecodeurContrat.lecture([MachineApi].self, statut: 200, corps: corps)
        guard case .datee(let charge, let message) = lecture else {
            Issue.record("attendu .datee, obtenu \(lecture)")
            return
        }
        #expect(charge?.isEmpty == true)
        #expect(message?.hasPrefix("PC absent") == true)
        #expect(lecture.erreur == nil)
        #expect(!lecture.releveFrais)
    }

    @Test("PC absent, rien de connu : data null reste .datee")
    func pcAbsentSansDonnees() {
        let corps = donnees(#"{"pcOnline":false,"stale":true,"data":null,"message":"PC absent"}"#)
        let lecture = DecodeurContrat.lecture([MachineApi].self, statut: 200, corps: corps)
        guard case .datee(let charge, _) = lecture else {
            Issue.record("attendu .datee, obtenu \(lecture)")
            return
        }
        #expect(charge == nil)
    }

    /// Le serveur n'émet jamais ça. Si ça arrive, c'est un défaut à voir — pas
    /// un PC éteint, qui ferait chercher au mauvais endroit.
    @Test("pcOnline vrai sans données : rupture de contrat, pas un PC éteint")
    func contratRompu() throws {
        let corps = donnees(#"{"pcOnline":true,"stale":false,"data":null}"#)
        let lecture = DecodeurContrat.lecture([MachineApi].self, statut: 200, corps: corps)
        let erreur = try #require(lecture.erreur)
        #expect(erreur.genre == .contratRompu)
    }

    @Test("/health n'est pas enveloppée")
    func santeNue() throws {
        let corps = donnees(#"{"ok":true,"pcOnline":false}"#)
        let sante = try DecodeurContrat.nu(SanteApi.self, statut: 200, corps: corps).get()
        #expect(sante.ok)
        #expect(!sante.pcOnline)
    }

    @Test("les jauges distinguent « pas de mesure » de « zéro »")
    func jauges() throws {
        let corps = donnees(#"{"pcOnline":true,"stale":false,"data":{"contextPct":null,"active":false}}"#)
        let lecture = DecodeurContrat.lecture(JaugesApi.self, statut: 200, corps: corps)
        let jauges = try #require(lecture.charge)
        #expect(jauges.contextPct == nil)
        #expect(!jauges.active)
    }
}
