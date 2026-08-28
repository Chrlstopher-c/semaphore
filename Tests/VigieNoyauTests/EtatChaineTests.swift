import Foundation
import Testing

@testable import VigieNoyau

@Suite("État de la chaîne — ce que /health permet de conclure")
struct EtatChaineTests {

    private func sante(_ ok: Bool, _ pc: Bool) -> SanteApi {
        SanteApi(ok: ok, pcOnline: pc)
    }

    @Test("sonde absente : on n'affirme rien")
    func sondeAbsente() {
        #expect(EtatChaine.lire(sante: nil, posteJoignable: true) == .inconnu)
        #expect(EtatChaine.lire(sante: nil, posteJoignable: nil).alerte == nil)
    }

    @Test("control plane muet : le verdict prime sur l'état du poste")
    func controlPlaneMuet() {
        #expect(EtatChaine.lire(sante: sante(false, true), posteJoignable: true) == .controlPlaneMuet)
        #expect(EtatChaine.lire(sante: sante(false, false), posteJoignable: false) == .controlPlaneMuet)
        #expect(EtatChaine.controlPlaneMuet.alerte != nil)
    }

    /// Le défaut réel du 14/08 : la machine tourne, son superviseur non, et
    /// toutes les routes du harness répondent « absente ».
    @Test("poste joignable mais invisible du control plane : superviseur tombé")
    func superviseurTombe() {
        #expect(EtatChaine.lire(sante: sante(true, false), posteJoignable: true) == .superviseurTombe)
        #expect(EtatChaine.superviseurTombe.alerte != nil)
    }

    @Test("poste éteint : détaché, et on se tait")
    func posteDetache() {
        #expect(EtatChaine.lire(sante: sante(true, false), posteJoignable: false) == .posteDetache)
        #expect(EtatChaine.lire(sante: sante(true, false), posteJoignable: nil) == .posteDetache)
        #expect(EtatChaine.posteDetache.alerte == nil)
    }

    @Test("les deux d'accord : rien à dire")
    func saine() {
        #expect(EtatChaine.lire(sante: sante(true, true), posteJoignable: true) == .saine)
        #expect(EtatChaine.saine.alerte == nil)
    }

    /// `☠` `pcOnline` vrai fait verdict à lui seul : si le control plane tient
    /// le lien, un `/api/status` en retard ne doit pas produire une fausse alerte.
    @Test("relevé du poste en retard : pas d'alerte inventée")
    func releveEnRetard() {
        #expect(EtatChaine.lire(sante: sante(true, true), posteJoignable: false) == .saine)
    }
}
