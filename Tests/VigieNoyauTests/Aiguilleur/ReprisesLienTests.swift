import Foundation
import Testing
@testable import VigieNoyau

// Liaison morte et reprises du client de l'aiguilleur : une liaison qui ne répond plus à ses pings est refaite, une
// liaison vivante ne l'est pas, et un changement de réseau (reconnecter) la refait tout de suite.

/// Lien mort : rien ne revient et aucun pong ; seul `fermer` le débloque, comme un TCP qui ne répond plus.
actor TransportMuet: TransportAiguilleur {
    private var ferme = false
    private var attente: CheckedContinuation<ProtocoleAiguilleur.DeAiguilleur, Error>?

    func envoyer(_ message: ProtocoleAiguilleur.VersAiguilleur) async throws {}

    func recevoir() async throws -> ProtocoleAiguilleur.DeAiguilleur {
        if ferme { throw ErreurAiguilleur("lien fermé") }
        return try await withCheckedThrowingContinuation { attente = $0 }
    }

    func fermer() async {
        ferme = true
        attente?.resume(throwing: ErreurAiguilleur("lien fermé"))
        attente = nil
    }

    func sonder(surPong: @escaping @Sendable () -> Void) async {}
}

struct ReprisesLienTests {
    @Test func unLienMortEstRefaitSansAttendreLaFermeture() async throws {
        let compteur = CompteurOuvertures()
        let rec = Enregistreur()
        let etat = ClientAiguilleur.Etat(adresse: "http://127.0.0.1:9", membre: "aaaaaaaaaaaa", jeton: "jeton-test")
        let client = ClientAiguilleur(
            etat: etat, graines: .generer(), nomAppareil: "iphone-test",
            surEtat: { await rec.noterEtat($0) }, surLien: { await rec.noterLien($0) },
            fabrique: { _, _ in compteur.ajouter(); return TransportMuet() }, delais: .rapides
        )
        await client.demarrer()
        try await attendreVrai { compteur.valeur >= 2 }
        await client.arreter()
    }

    @Test func unLienQuiRépondAuxPingsResteOuvert() async throws {
        let compteur = CompteurOuvertures()
        let etat = ClientAiguilleur.Etat(adresse: "http://127.0.0.1:9", membre: "aaaaaaaaaaaa", jeton: "jeton-test")
        let client = ClientAiguilleur(
            etat: etat, graines: .generer(), nomAppareil: "iphone-test",
            surEtat: { _ in }, surLien: { _ in },
            fabrique: { _, _ in compteur.ajouter(); return TransportFaux() }, delais: .rapides
        )
        await client.demarrer()
        try await attendreVrai { compteur.valeur == 1 }
        try await Task.sleep(for: .milliseconds(800))
        #expect(compteur.valeur == 1, "un lien qui répond aux pings n'est pas refait")
        await client.arreter()
    }

    @Test func reconnecterRefaitLeLienTout() async throws {
        let compteur = CompteurOuvertures()
        let etat = ClientAiguilleur.Etat(adresse: "http://127.0.0.1:9", membre: "aaaaaaaaaaaa", jeton: "jeton-test")
        let client = ClientAiguilleur(
            etat: etat, graines: .generer(), nomAppareil: "iphone-test",
            surEtat: { _ in }, surLien: { _ in },
            fabrique: { _, _ in compteur.ajouter(); return TransportFaux() }, delais: .rapides
        )
        await client.demarrer()
        try await attendreVrai { compteur.valeur == 1 }
        await client.reconnecter()
        try await attendreVrai { compteur.valeur == 2 }
        await client.arreter()
    }
}
