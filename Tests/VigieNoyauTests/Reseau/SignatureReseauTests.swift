import Foundation
import Testing

@testable import VigieNoyau

#if canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif

// Les ordres signés : la signature se vérifie avec la clé du signataire, le texte porte les champs attendus, et le
// nonce est absent ou de 32 caractères hexadécimaux. Le préfixe de domaine empêche de rejouer un ordre en charte.

struct SignatureReseauTests {
    @Test func ordreSigneSeVerifieAvecLaCleDuSignataire() async throws {
        let cle = Chiffrement.Identite.generer()
        let signataire = SignataireTest(membre: FabriqueCharte.chef, cle: cle)
        let ordre = try await SignatureReseau.signerOrdre(
            reseau: FabriqueCharte.reseau, cible: FabriqueCharte.serveur, action: .redemarrer, par: signataire,
            le: FabriqueCharte.date, nonce: "00112233445566778899aabbccddeeff")
        let publique = try Curve25519.Signing.PublicKey(rawRepresentation: cle.publique.signature)
        let signature = try Chiffrement.Octets.depuisBase64url(ordre.signature, longueur: 64)
        #expect(publique.isValidSignature(signature, for: Data((SignatureReseau.prefixeOrdre + ordre.texte).utf8)))
        #expect(!publique.isValidSignature(signature, for: Data((SignatureReseau.prefixeCharte + ordre.texte).utf8)))
        let lu = try ValeurJSON.lire(ordre.texte)
        #expect(lu["action"] == .texte("redemarrer"))
        #expect(lu["cible"] == .texte(FabriqueCharte.serveur))
        #expect(lu["par"] == .texte(FabriqueCharte.chef))
        #expect(lu["nonce"] == .texte("00112233445566778899aabbccddeeff"))
    }

    @Test func sansNonceLeNonceFaitTrenteDeuxHexadecimaux() async throws {
        let signataire = SignataireTest(membre: FabriqueCharte.chef, cle: Chiffrement.Identite.generer())
        let ordre = try await SignatureReseau.signerOrdre(
            reseau: FabriqueCharte.reseau, cible: FabriqueCharte.serveur, action: .pause, par: signataire,
            le: FabriqueCharte.date)
        guard case .texte(let nonce)? = try ValeurJSON.lire(ordre.texte)["nonce"] else {
            Issue.record("nonce absent de l'ordre")
            return
        }
        #expect(nonce.count == 32)
        #expect(nonce.allSatisfy { "0123456789abcdef".contains($0) })
    }

    @Test func laCharteSigneeGardeLeTexteExactDeSonJSON() async throws {
        let cle = Chiffrement.Identite.generer()
        let brut = FabriqueCharte.charte(
            version: 1, chefs: [FabriqueCharte.chef], par: FabriqueCharte.chef,
            membres: [FabriqueCharte.membre(FabriqueCharte.chef, .pair, cle)])
        let c = try CharteReseau(brut: brut)
        let signee = try await SignatureReseau.signerCharte(
            c, par: SignataireTest(membre: FabriqueCharte.chef, cle: cle))
        let attendu = try c.brut.texteJSON()
        #expect(signee.texte == attendu)
        #expect(SignatureReseau.verifier(signee)?.version == 1)
    }
}
