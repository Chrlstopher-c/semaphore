import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Testing
@testable import VigieNoyau

// Vecteurs croisés produits par Quart (`commun/chiffrement/vecteurs-croises.ts`, graines fixées) : chaque octet
// de la poignée et de chaque trame doit être reproduit à l'identique, dans les deux sens.

struct VecteurIdentite: Decodable {
    let graineDh: String
    let graineSignature: String
    let publique: String
}

struct VecteurEphemere: Decodable {
    let graine: String
    let publique: String
}

struct VecteurPoignee: Decodable {
    let canal: String
    let ephemereI: VecteurEphemere
    let ephemereR: VecteurEphemere
    let messageInitial: Chiffrement.MessageInitial
    let messageReponse: Chiffrement.MessageReponse
}

struct VecteurTrame: Decodable {
    let sens: String
    let clair: String
    let trame: String
}

struct VecteursChiffrement: Decodable {
    struct Identites: Decodable {
        let I: VecteurIdentite
        let R: VecteurIdentite
    }

    struct Canal: Decodable {
        let trames: [VecteurTrame]
    }

    let identites: Identites
    let poignee: VecteurPoignee
    let canal: Canal
}

enum VecteursFixtures {
    static func charger() throws -> VecteursChiffrement {
        let url = try #require(Bundle.module.url(
            forResource: "Echantillons/chiffrement-vecteurs-croises", withExtension: "json"
        ))
        return try JSONDecoder().decode(VecteursChiffrement.self, from: Data(contentsOf: url))
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    static func depuisHex(_ texte: String) -> Data {
        var sortie = Data()
        var index = texte.startIndex
        while index < texte.endIndex {
            let fin = texte.index(index, offsetBy: 2)
            sortie.append(UInt8(texte[index..<fin], radix: 16) ?? 0)
            index = fin
        }
        return sortie
    }
}

struct ChiffrementVecteursTests {
    @Test func identitesDeGrainesDonnentLesPubliquesDeQuart() throws {
        let v = try VecteursFixtures.charger()
        let i = try Chiffrement.Identite.depuisGraines(
            dh: VecteursFixtures.depuisHex(v.identites.I.graineDh),
            signature: VecteursFixtures.depuisHex(v.identites.I.graineSignature)
        )
        let r = try Chiffrement.Identite.depuisGraines(
            dh: VecteursFixtures.depuisHex(v.identites.R.graineDh),
            signature: VecteursFixtures.depuisHex(v.identites.R.graineSignature)
        )
        #expect(Chiffrement.Identites.exporter(i.publique) == v.identites.I.publique)
        #expect(Chiffrement.Identites.exporter(r.publique) == v.identites.R.publique)
    }

    @Test func poigneeRejoueLesMessagesDeQuartOctetPourOctet() throws {
        let v = try VecteursFixtures.charger()
        let (i, r) = try identitesDeVecteurs(v)
        let eI = try ephemere(v.poignee.ephemereI)
        let eR = try ephemere(v.poignee.ephemereR)
        let (message, attente) = try Chiffrement.Poignee.initier(
            moi: i, destinataire: r.publique, canal: v.poignee.canal, ephemere: eI
        )
        #expect(message == v.poignee.messageInitial)
        let cleI = Chiffrement.Identites.exporter(i.publique)
        let (reponse, _) = try Chiffrement.Poignee.repondre(
            moi: r, message: message, accepte: { Chiffrement.Identites.exporter($0) == cleI }, ephemere: eR
        )
        #expect(reponse == v.poignee.messageReponse)
        _ = try Chiffrement.Poignee.terminer(attente: attente, reponse: reponse)
    }

    @Test func trameDeQuartEstReproduiteEtLueDansLesDeuxSens() async throws {
        let v = try VecteursFixtures.charger()
        let (i, r) = try identitesDeVecteurs(v)
        let (message, attente) = try Chiffrement.Poignee.initier(
            moi: i, destinataire: r.publique, canal: v.poignee.canal, ephemere: try ephemere(v.poignee.ephemereI)
        )
        let cleI = Chiffrement.Identites.exporter(i.publique)
        let (reponse, canalR) = try Chiffrement.Poignee.repondre(
            moi: r, message: message, accepte: { Chiffrement.Identites.exporter($0) == cleI },
            ephemere: try ephemere(v.poignee.ephemereR)
        )
        let canalI = try Chiffrement.Poignee.terminer(attente: attente, reponse: reponse)
        for trame in v.canal.trames {
            let clair = VecteursFixtures.depuisHex(trame.clair)
            let attendue = VecteursFixtures.depuisHex(trame.trame)
            let (emetteur, recepteur) = trame.sens == "i>r" ? (canalI, canalR) : (canalR, canalI)
            #expect(try await emetteur.chiffrer(clair) == attendue)
            #expect(try await recepteur.dechiffrer(attendue) == clair)
        }
    }

    fileprivate func identitesDeVecteurs(
        _ v: VecteursChiffrement
    ) throws -> (Chiffrement.Identite, Chiffrement.Identite) {
        let i = try Chiffrement.Identite.depuisGraines(
            dh: VecteursFixtures.depuisHex(v.identites.I.graineDh),
            signature: VecteursFixtures.depuisHex(v.identites.I.graineSignature)
        )
        let r = try Chiffrement.Identite.depuisGraines(
            dh: VecteursFixtures.depuisHex(v.identites.R.graineDh),
            signature: VecteursFixtures.depuisHex(v.identites.R.graineSignature)
        )
        return (i, r)
    }

    fileprivate func ephemere(_ vecteur: VecteurEphemere) throws -> Curve25519.KeyAgreement.PrivateKey {
        try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: VecteursFixtures.depuisHex(vecteur.graine))
    }
}
