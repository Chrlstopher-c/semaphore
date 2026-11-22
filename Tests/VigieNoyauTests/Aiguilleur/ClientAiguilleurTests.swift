import Foundation
import Testing
@testable import VigieNoyau

// Le client de l'aiguilleur sans réseau : un transport factice rejoue les messages de l'aiguilleur et garde ceux
// que le client envoie. Les délais sont courts pour que les échecs se voient vite.

/// Ce que le client rapporte à l'appli : états et liens, dans l'ordre.
actor Enregistreur {
    private(set) var liens: [ClientAiguilleur.Lien] = []
    private(set) var etats: [ClientAiguilleur.Etat] = []

    var dernierEtat: ClientAiguilleur.Etat? { etats.last }

    func noterLien(_ lien: ClientAiguilleur.Lien) { liens.append(lien) }
    func noterEtat(_ etat: ClientAiguilleur.Etat) { etats.append(etat) }
    func contient(_ lien: ClientAiguilleur.Lien) -> Bool { liens.contains(lien) }

    func contient(where condition: (ClientAiguilleur.Lien) -> Bool) -> Bool { liens.contains(where: condition) }

    func attendreLien(
        secondes: Double = 3, _ condition: @escaping @Sendable (ClientAiguilleur.Lien) -> Bool
    ) async throws {
        try await attendreVrai(secondes: secondes) { await self.contient(where: condition) }
    }
}

/// Transport factice : `pousser` fait arriver un message de l'aiguilleur, `envoyes` relit ce que le client a dit.
actor TransportFaux: TransportAiguilleur {
    private(set) var envoyes: [ProtocoleAiguilleur.VersAiguilleur] = []
    private(set) var ferme = false
    private var file: [ProtocoleAiguilleur.DeAiguilleur] = []
    private var attente: CheckedContinuation<ProtocoleAiguilleur.DeAiguilleur, Error>?

    func envoyer(_ message: ProtocoleAiguilleur.VersAiguilleur) async throws {
        envoyes.append(message)
    }

    func recevoir() async throws -> ProtocoleAiguilleur.DeAiguilleur {
        if !file.isEmpty { return file.removeFirst() }
        if ferme { throw ErreurAiguilleur("lien fermé") }
        return try await withCheckedThrowingContinuation { attente = $0 }
    }

    func fermer() async {
        ferme = true
        attente?.resume(throwing: ErreurAiguilleur("lien fermé"))
        attente = nil
    }

    func pousser(_ message: ProtocoleAiguilleur.DeAiguilleur) {
        guard let enAttente = attente else { return file.append(message) }
        attente = nil
        enAttente.resume(returning: message)
    }

    func ouvrirVers(_ noeud: String) -> Bool {
        envoyes.contains { message in
            if case let .ouvrir(_, vers) = message { return vers == noeud }
            return false
        }
    }
}

/// Attend qu'une condition devienne vraie ; échoue au bout de `secondes`.
func attendreVrai(secondes: Double = 3, _ condition: @Sendable () async -> Bool) async throws {
    let fin = ContinuousClock.now.advanced(by: .milliseconds(Int(secondes * 1000)))
    while !(await condition()) {
        if ContinuousClock.now > fin { throw ErreurAiguilleur("délai dépassé dans le test") }
        try await Task.sleep(for: .milliseconds(20))
    }
}

private let moi = "aaaaaaaaaaaa"
private let noeud = "bbbbbbbbbbbb"

private func etatInitial() -> ClientAiguilleur.Etat {
    ClientAiguilleur.Etat(adresse: "http://127.0.0.1:9", membre: moi, jeton: "jeton-test")
}

private func clientTest(
    _ faux: TransportFaux, _ rec: Enregistreur, etat: ClientAiguilleur.Etat, graines: GrainesIdentite
) -> ClientAiguilleur {
    ClientAiguilleur(
        etat: etat, graines: graines, nomAppareil: "iphone-test",
        surEtat: { await rec.noterEtat($0) }, surLien: { await rec.noterLien($0) },
        fabrique: { _, _ in faux }, delais: .rapides
    )
}

struct ClientAiguilleurTests {
    @Test func presenceChoisitLeNoeudEtOuvreUnCanalDAppairage() async throws {
        let faux = TransportFaux()
        let rec = Enregistreur()
        let graines = GrainesIdentite.generer()
        let client = clientTest(faux, rec, etat: etatInitial(), graines: graines)
        await client.demarrer()
        await faux.pousser(.presence([
            .init(id: moi, enLigne: true, genre: "appareil"),
            .init(id: noeud, enLigne: true, genre: "noeud"),
        ]))
        try await attendreVrai { await faux.ouvrirVers(noeud) }
        try await rec.attendreLien { $0 == .attenteAccord(empreinte: graines.empreinte) }
        #expect(await rec.dernierEtat?.noeud == noeud)
        await client.arreter()
    }

    @Test func sansNoeudEnLigneLeLienCherche() async throws {
        let faux = TransportFaux()
        let rec = Enregistreur()
        let client = clientTest(faux, rec, etat: etatInitial(), graines: .generer())
        await client.demarrer()
        await faux.pousser(.presence([.init(id: moi, enLigne: true, genre: "appareil")]))
        try await rec.attendreLien { $0 == .rechercheNoeud }
        #expect(await faux.ouvrirVers(noeud) == false)
        await client.arreter()
    }

    @Test func requeteSansLienOuvertEchoueApresLeDelai() async throws {
        let faux = TransportFaux()
        let client = clientTest(faux, Enregistreur(), etat: etatInitial(), graines: .generer())
        await client.demarrer()
        await #expect(throws: ErreurAiguilleur.self) {
            try await client.requete(methode: "GET", chemin: "/api/etat", corps: nil)
        }
        await client.arreter()
    }

    @Test func appairageAccepteMemoriseLIdentiteDuNoeud() async throws {
        let faux = TransportFaux()
        let rec = Enregistreur()
        var etat = etatInitial()
        etat.noeud = noeud
        let client = clientTest(faux, rec, etat: etat, graines: .generer())
        let identiteNoeud = try GrainesIdentite.generer().identite().publique
        await client.appairageAccepte(membre: noeud, nom: "noeud-test", identite: identiteNoeud)
        #expect(await rec.dernierEtat?.identiteNoeud == Chiffrement.Identites.exporter(identiteNoeud))
        #expect(await rec.dernierEtat?.nomNoeud == "noeud-test")
        #expect(await client.identitePairee(noeud) == identiteNoeud)
        #expect(await client.identitePairee("cccccccccccc") == nil)
    }

    @Test func revocationRefuseLeLienEtFermeLeTransport() async throws {
        let faux = TransportFaux()
        let rec = Enregistreur()
        let client = clientTest(faux, rec, etat: etatInitial(), graines: .generer())
        await client.demarrer()
        await client.recevoir(canal: "c1", message: .revocation)
        #expect(await rec.contient(.revoque))
        #expect(await faux.ferme)
        await client.arreter()
    }
}
