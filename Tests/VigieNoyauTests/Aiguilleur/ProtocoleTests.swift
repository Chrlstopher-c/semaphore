import Foundation
import Testing
@testable import VigieNoyau

// Les messages que Quart produit (vecteurs croisés, validés par ses schémas) doivent se décoder ici à l'identique.

private func exemple(_ chemin: [String]) throws -> String {
    let url = try #require(Bundle.module.url(
        forResource: "Echantillons/chiffrement-vecteurs-croises", withExtension: "json"
    ))
    let racine = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    var noeud: Any = racine
    for cle in chemin {
        guard let suivant = (noeud as? [String: Any])?[cle] else { throw ErreurChiffrement("exemple absent : \(cle)") }
        noeud = suivant
    }

    let octets = try JSONSerialization.data(withJSONObject: noeud)
    return String(decoding: octets, as: UTF8.self)
}

struct ProtocoleTests {
    @Test func messagesDeLAiguilleurDecodesCommeDansQuart() throws {
        #expect(try ProtocoleAiguilleur.decoderDeAiguilleur(exemple(["protocole", "aiguilleur", "presence"]))
            == .presence([.init(id: "a1b2c3d4e5f6", enLigne: true)]))
        #expect(try ProtocoleAiguilleur.decoderDeAiguilleur(exemple(["protocole", "aiguilleur", "erreur"]))
            == .erreur(canal: "ap-1", motif: "hors-ligne"))
        #expect(try ProtocoleAiguilleur.decoderDeAiguilleur(exemple(["protocole", "aiguilleur", "donnees"]))
            == .donnees(canal: "ap-1", charge: "{\"t\":\"accord\"}"))
    }

    @Test func messagesEnClairDecodesCommeDansQuart() throws {
        let identite = try exemple(["protocole", "enClair", "presentation"])
        #expect(try ProtocoleAiguilleur.decoderEnClair(identite).isPresentation)
        #expect(try ProtocoleAiguilleur.decoderEnClair(exemple(["protocole", "enClair", "accord"])) == .accord)
        #expect(try ProtocoleAiguilleur.decoderEnClair(exemple(["protocole", "enClair", "refus"]))
            == .refus(raison: "refusé par le nœud visé"))
    }

    @Test func messagesDuLienAllerEtRetour() throws {
        let api = try exemple(["protocole", "chiffre", "api"])
        let decode = try ProtocoleAiguilleur.decoderDuLien(Data(api.utf8))
        #expect(decode == .api(ref: "r1", methode: "GET", chemin: "/api/etat", corps: nil))
        let reponse = try ProtocoleAiguilleur.encoder(ProtocoleAiguilleur.DuLien.apiReponse(
            ref: "r1", statut: 200, corps: "{\"machine\":\"tour\"}"
        ))
        #expect(try ProtocoleAiguilleur.decoderDuLien(reponse)
            == .apiReponse(ref: "r1", statut: 200, corps: "{\"machine\":\"tour\"}"))
    }

    @Test func unMessageHorsProtocoleEstRefuse() {
        #expect(throws: ErreurChiffrement.self) { try ProtocoleAiguilleur.decoderDeAiguilleur("{\"t\":\"inconnu\"}") }
        #expect(throws: ErreurChiffrement.self) { try ProtocoleAiguilleur.decoderEnClair("pas du json") }
        #expect(throws: ErreurChiffrement.self) { try ProtocoleAiguilleur.decoderDuLien(Data("{\"t\":\"api\"}".utf8)) }
    }

    @Test func reglageNeSActiveQueSCompletEtValide() {
        var r = ReglagesAiguilleur.defaut
        #expect(!r.actif)
        r = ReglagesAiguilleur(passerParAiguilleur: true, adresse: "https://relais.example.com", code: "ABCD-1234")
        #expect(r.actif)
        r.code = "abcd-1234"
        #expect(!r.actif)
        r.code = "ABCD-1234"
        r.adresse = "ftp://x"
        #expect(!r.actif)
    }
}

private extension ProtocoleAiguilleur.EnClair {
    var isPresentation: Bool {
        if case .presentation = self { return true }
        return false
    }
}
