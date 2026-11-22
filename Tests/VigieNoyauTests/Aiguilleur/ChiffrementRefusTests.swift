import Foundation
import Testing
@testable import VigieNoyau

// Refus du chiffrement de bout en bout : rejeu, altération, réordonnancement, troncature, réflexion, usurpation.

private struct CanauxEtablis {
    let initiateur: Chiffrement.Canal
    let repondeur: Chiffrement.Canal
}

private func etablir(accepte: Bool = true) throws -> CanauxEtablis {
    let moi = Chiffrement.Identite.generer()
    let toi = Chiffrement.Identite.generer()
    let (message, attente) = try Chiffrement.Poignee.initier(moi: moi, destinataire: toi.publique, canal: "essai")
    let cleMoi = Chiffrement.Identites.exporter(moi.publique)
    let (reponse, repondeur) = try Chiffrement.Poignee.repondre(
        moi: toi, message: message, accepte: { accepte && Chiffrement.Identites.exporter($0) == cleMoi }
    )
    let initiateur = try Chiffrement.Poignee.terminer(attente: attente, reponse: reponse)
    return CanauxEtablis(initiateur: initiateur, repondeur: repondeur)
}

private func octets(_ texte: String) -> Data { Data(texte.utf8) }

private func alteree(_ data: Data, position: Int) -> Data {
    var copie = data
    copie[copie.startIndex + position] ^= 0x80
    return copie
}

struct ChiffrementRefusTests {
    @Test func trameNominaleEstLue() async throws {
        let c = try etablir()
        let trame = try await c.initiateur.chiffrer(octets("bonjour"))
        #expect(try await c.repondeur.dechiffrer(trame) == octets("bonjour"))
    }

    @Test func rejeuRefuse() async throws {
        let c = try etablir()
        let trame = try await c.initiateur.chiffrer(octets("x"))
        _ = try await c.repondeur.dechiffrer(trame)
        await #expect(throws: ErreurChiffrement.self) { try await c.repondeur.dechiffrer(trame) }
    }

    @Test func reordonnancementRefusepuisLaSuiteReprend() async throws {
        let c = try etablir()
        let t1 = try await c.initiateur.chiffrer(octets("1"))
        let t2 = try await c.initiateur.chiffrer(octets("2"))
        await #expect(throws: ErreurChiffrement.self) { try await c.repondeur.dechiffrer(t2) }
        #expect(try await c.repondeur.dechiffrer(t1) == octets("1"))
        #expect(try await c.repondeur.dechiffrer(t2) == octets("2"))
    }

    @Test func troncatureRefusee() async throws {
        let c = try etablir()
        let trame = try await c.initiateur.chiffrer(octets("texte assez long"))
        await #expect(throws: ErreurChiffrement.self) { try await c.repondeur.dechiffrer(trame.dropLast()) }
        await #expect(throws: ErreurChiffrement.self) { try await c.repondeur.dechiffrer(Data()) }
    }

    @Test func alterationRefusee() async throws {
        let c = try etablir()
        let trame = try await c.initiateur.chiffrer(octets("intact"))
        await #expect(throws: ErreurChiffrement.self) {
            try await c.repondeur.dechiffrer(alteree(trame, position: trame.count - 1))
        }
    }

    @Test func reflexionRefusee() async throws {
        let c = try etablir()
        let trame = try await c.initiateur.chiffrer(octets("miroir"))
        await #expect(throws: ErreurChiffrement.self) { try await c.initiateur.dechiffrer(trame) }
    }

    @Test func identiteInconnueRefuseeAvantTout() throws {
        let moi = Chiffrement.Identite.generer()
        let toi = Chiffrement.Identite.generer()
        let (message, _) = try Chiffrement.Poignee.initier(moi: moi, destinataire: toi.publique, canal: "essai")
        #expect(throws: ErreurChiffrement.self) {
            try Chiffrement.Poignee.repondre(moi: toi, message: message, accepte: { _ in false })
        }
    }

    @Test func usurpationAvecMauvaiseSignatureRefusee() throws {
        let moi = Chiffrement.Identite.generer()
        let toi = Chiffrement.Identite.generer()
        let intrus = Chiffrement.Identite.generer()
        let (message, _) = try Chiffrement.Poignee.initier(moi: moi, destinataire: toi.publique, canal: "essai")
        let usurpe = Chiffrement.MessageInitial(
            version: message.version, canal: message.canal,
            identite: Chiffrement.Identites.exporter(intrus.publique),
            ephemere: message.ephemere, signature: message.signature
        )
        #expect(throws: ErreurChiffrement.self) {
            try Chiffrement.Poignee.repondre(moi: toi, message: usurpe, accepte: { _ in true })
        }
    }

    @Test func messageAdresseAAutreRepondeurRefuse() throws {
        let moi = Chiffrement.Identite.generer()
        let toi = Chiffrement.Identite.generer()
        let autre = Chiffrement.Identite.generer()
        let (message, _) = try Chiffrement.Poignee.initier(moi: moi, destinataire: toi.publique, canal: "essai")
        #expect(throws: ErreurChiffrement.self) {
            try Chiffrement.Poignee.repondre(moi: autre, message: message, accepte: { _ in true })
        }
    }

    @Test func reponseRejoueeDunAutreEchangeRefusee() throws {
        let moi = Chiffrement.Identite.generer()
        let toi = Chiffrement.Identite.generer()
        let (premier, attentePremier) = try Chiffrement.Poignee.initier(
            moi: moi, destinataire: toi.publique, canal: "essai"
        )
        let (second, _) = try Chiffrement.Poignee.initier(moi: moi, destinataire: toi.publique, canal: "essai")
        let (reponseSecond, _) = try Chiffrement.Poignee.repondre(moi: toi, message: second, accepte: { _ in true })
        #expect(throws: ErreurChiffrement.self) {
            try Chiffrement.Poignee.terminer(attente: attentePremier, reponse: reponseSecond)
        }
    }

    @Test func cleEd25519NonCanoniqueRefusee() {
        let nonCanonique = Data([0xed] + Array(repeating: UInt8(0xff), count: 30) + [0x7f])
        let identite = Data(repeating: 0, count: 32) + nonCanonique
        #expect(throws: ErreurChiffrement.self) {
            try Chiffrement.Identites.importer(Chiffrement.Octets.versBase64url(identite))
        }
    }

    @Test func base64urlMalFormeRefuse() {
        #expect(throws: ErreurChiffrement.self) { try Chiffrement.Octets.depuisBase64url("ab+/") }
        #expect(throws: ErreurChiffrement.self) { try Chiffrement.Octets.depuisBase64url("abcd", longueur: 2) }
    }
}
