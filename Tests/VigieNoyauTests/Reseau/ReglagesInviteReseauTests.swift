import Foundation
import Testing

@testable import VigieNoyau

// Les réglages d'un invité : aller-retour JSON sans perte, et refus des valeurs hors des bornes de
// `commun/invites.ts`.

struct ReglagesInviteReseauTests {
    @Test func parDefautFaitUnAllerRetourJSON() throws {
        let reglages = ReglagesInvite.parDefaut(machine: FabriqueCharte.serveur)
        #expect(try ReglagesInvite.lire(reglages.valeurJSON) == reglages)
    }

    @Test func unModeleOuUnEffortInconnuEstRefuse() {
        var hors = ReglagesInvite.parDefaut(machine: nil)
        hors.modeles["gpt"] = ["low"]
        #expect(hors.defaut() == "modeles")
        var effort = ReglagesInvite.parDefaut(machine: nil)
        effort.modeles["haiku"] = ["ultra"]
        #expect(effort.defaut() == "modeles")
    }

    @Test func lesBornesSontRespectees() {
        var simultanees = ReglagesInvite.parDefaut(machine: nil)
        simultanees.simultanees = 0
        var part = ReglagesInvite.parDefaut(machine: nil)
        part.partSemaine = 101
        var machines = ReglagesInvite.parDefaut(machine: nil)
        machines.machines = ["pas-un-identifiant"]
        #expect(simultanees.defaut() == "simultanees")
        #expect(part.defaut() == "partSemaine")
        #expect(machines.defaut() == "machines")
    }
}
