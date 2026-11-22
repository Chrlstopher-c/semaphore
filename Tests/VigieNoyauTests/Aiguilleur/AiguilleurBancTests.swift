import Foundation
import Testing
@testable import VigieNoyau

// Banc réel (banc/lancer-banc.sh) : un aiguilleur Quart et un nœud de banc sur 127.0.0.1, parlés avec le vrai
// protocole et le vrai chiffrement. Désactivé hors banc : QUART_AIGUILLEUR_BANC pointe le fichier JSON du banc.

private struct DescriptionBanc: Decodable {
    let adresse: String
    let codeAppareil: String
    let codeIntrus: String
    let noeud: String
}

private let bancActif = ProcessInfo.processInfo.environment["QUART_AIGUILLEUR_BANC"] != nil

private func chargerBanc() throws -> DescriptionBanc {
    guard let chemin = ProcessInfo.processInfo.environment["QUART_AIGUILLEUR_BANC"] else {
        throw ErreurAiguilleur("QUART_AIGUILLEUR_BANC absent")
    }
    let octets = try Data(contentsOf: URL(fileURLWithPath: chemin))
    return try JSONDecoder().decode(DescriptionBanc.self, from: octets)
}

struct AiguilleurBancTests {
    @Test(.enabled(if: bancActif), .timeLimit(.minutes(2)))
    func appareilAppaireServLApiDuNoeudDansLeCanalChiffre() async throws {
        let banc = try chargerBanc()
        let graines = GrainesIdentite.generer()
        let etat = try await ClientAiguilleur.appairer(
            adresse: try urlBanc(banc), code: banc.codeAppareil, nom: "appareil-banc", graines: graines
        )
        let rec = Enregistreur()
        let client = ClientAiguilleur(
            etat: etat, graines: graines, nomAppareil: "appareil-banc",
            surEtat: { await rec.noterEtat($0) }, surLien: { await rec.noterLien($0) }
        )
        await client.demarrer()
        try await rec.attendreLien(secondes: 30) { $0 == .ouvert }
        #expect(await rec.contient(.attenteAccord(empreinte: graines.empreinte)))
        let reponse = try await client.requete(methode: "GET", chemin: "/api/etat", corps: nil)
        #expect(reponse.statut == 200)
        #expect(reponse.corps == "{\"machine\":\"noeud-banc\"}")
        #expect(await rec.dernierEtat?.noeud == banc.noeud)
        #expect(await rec.dernierEtat?.identiteNoeud != nil)
        await client.arreter()
    }

    @Test(.enabled(if: bancActif), .timeLimit(.minutes(2)))
    func identiteNonApparieeEstRefuseeParLeNoeud() async throws {
        let banc = try chargerBanc()
        var etat = try await ClientAiguilleur.appairer(
            adresse: try urlBanc(banc), code: banc.codeIntrus, nom: "intrus-banc", graines: .generer()
        )
        etat.noeud = banc.noeud
        etat.identiteNoeud = Chiffrement.Identites.exporter(try GrainesIdentite.generer().identite().publique)
        let rec = Enregistreur()
        let client = ClientAiguilleur(
            etat: etat, graines: .generer(), nomAppareil: "intrus-banc",
            surEtat: { await rec.noterEtat($0) }, surLien: { await rec.noterLien($0) }
        )
        await client.demarrer()
        try await rec.attendreLien(secondes: 30) { $0 == .refuse("non appairé") }
        #expect(await rec.contient(.ouvert) == false)
        await client.arreter()
    }
}

private func urlBanc(_ banc: DescriptionBanc) throws -> URL {
    guard let url = URL(string: banc.adresse) else { throw ErreurAiguilleur("adresse du banc illisible") }
    return url
}
