import Foundation
import Testing
@testable import VigieNoyau

// La minuterie de vivacité : décision de ping, de pong attendu et de liaison morte, à partir d'instants passés en
// paramètre (aucune horloge réelle).

struct VivaciteLiaisonTests {
    private let t0 = ContinuousClock.now

    private func minuterie() -> MinuterieVivacite {
        MinuterieVivacite(intervalle: .seconds(15), delaiPong: .seconds(10), depuis: t0)
    }

    @Test func pasDePingAvantLIntervalle() {
        let m = minuterie()
        #expect(m.action(t0.advanced(by: .seconds(14))) == .rien)
        #expect(m.action(t0.advanced(by: .seconds(15))) == .ping)
    }

    @Test func pingSansPongEstUneLiaisonMorteAuDelai() {
        var m = minuterie()
        let envoi = t0.advanced(by: .seconds(15))
        m.pingPartie(envoi)
        #expect(m.action(envoi.advanced(by: .seconds(9))) == .rien, "le pong peut encore arriver")
        #expect(m.action(envoi.advanced(by: .seconds(10))) == .morte)
    }

    @Test func unPongRepousseLeProchainPing() {
        var m = minuterie()
        let envoi = t0.advanced(by: .seconds(15))
        m.pingPartie(envoi)
        m.recu(envoi.advanced(by: .seconds(2)))
        #expect(m.action(envoi.advanced(by: .seconds(10))) == .rien, "la liaison a répondu : pas morte")
        #expect(m.action(envoi.advanced(by: .seconds(2) + .seconds(15))) == .ping)
    }

    @Test func uneTrameRecueVautActiviteEtRepousseLePing() {
        var m = minuterie()
        m.recu(t0.advanced(by: .seconds(12)))
        #expect(m.action(t0.advanced(by: .seconds(15))) == .rien)
        #expect(m.action(t0.advanced(by: .seconds(27))) == .ping)
    }

    @Test func attenteSuitLEcheanceCourante() {
        var m = minuterie()
        #expect(m.attente(t0) == .seconds(15))
        let envoi = t0.advanced(by: .seconds(15))
        m.pingPartie(envoi)
        #expect(m.attente(envoi) == .seconds(10), "la veille dort jusqu'à la fin du délai de pong")
        #expect(m.attente(envoi.advanced(by: .seconds(30))) == .zero, "jamais de durée négative")
    }

    @Test func pingForceEstDuTout() {
        var m = minuterie()
        let maintenant = t0.advanced(by: .seconds(3))
        #expect(m.action(maintenant) == .rien)
        m.forcerPing(maintenant)
        #expect(m.action(maintenant) == .ping, "retour au premier plan : ping sans attendre l'échéance")
    }

    @Test func pingForceAnnuleLAttenteDeLaPongPrecedente() {
        var m = minuterie()
        m.pingPartie(t0.advanced(by: .seconds(15)))
        m.forcerPing(t0.advanced(by: .seconds(16)))
        #expect(m.action(t0.advanced(by: .seconds(16))) == .ping)
    }
}
