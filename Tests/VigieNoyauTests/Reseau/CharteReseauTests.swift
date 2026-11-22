import Foundation
import Testing

@testable import VigieNoyau

#if canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif

// La charte lue, sa cohérence, sa signature et la garde du téléphone (`digne`). Le vecteur croisé a été signé
// par le serveur (`commun/charte.ts`, `signerCharte`) et vérifié par `verifierCharte` : Swift doit le tenir.

/// Charte signée par le TS serveur (genèse, version 3, un chef, un serveur, un invité sur le serveur).
private let texteVecteur =
    #"{"format":1,"reseau":"5e6f7a8b9c0d","nom":"Reseau de test","version":3,"chefs":["a1b2c3d4e"#
    + #"5f6"],"membres":[{"id":"a1b2c3d4e5f6","nom":"Chef","sorte":"pair","identite":"cdDhqENifm_h"#
    + #"qqcc80i0oXjgRcJbS7zKVu0dNDRqmQvdQT45tgLdnmpS1XehELBHogCGDim1HrkxGj6ee_77Tw","droits":{"voi"#
    + #"r":true,"piloter":true,"lancer":true,"remoteControl":true},"compte":null},{"id":"0f1e2d3c4"#
    + #"b5a","nom":"Machine","sorte":"serveur","identite":"h5p0Kxed6fWsoMnMJJ0fyBhsMJq1X6lSZpc5nJA"#
    + #"PrjmYSDvZ1cycmSGBbj8XhbUgj6qtUPWupXMyrjxegVYRGQ","droits":{"voir":true,"piloter":true,"lan"#
    + #"cer":true,"remoteControl":true},"compte":null},{"id":"9a8b7c6d5e4f","nom":"Invite","sorte""#
    + #":"pair","identite":"kJAcQ0pMz3T3FMKnpUpTmfkSdpRoVkZCbxiI79mskx7cFuYhZyEpYi8a0Dgomh3ATr9Afp"#
    + #"mN01jRJO64OdSFSw","droits":{"voir":false,"piloter":false,"lancer":false,"remoteControl":fa"#
    + #"lse},"compte":null,"invite":{"modeles":{"haiku":["low","medium","high"],"sonnet":["low","m"#
    + #"edium","high"]},"part5h":25,"partSemaine":25,"simultanees":2,"machines":["0f1e2d3c4b5a"],""#
    + #"surSaMachine":false,"prompt":"","acces":{"remoteControl":false,"terminaux":false,"sessions"#
    + #"Autres":false,"modules":false,"fichiersHors":false},"telemetrie":true}}],"le":"2026-11-22T"#
    + #"10:00:00.000Z","par":"a1b2c3d4e5f6","origine":"creation"}"#
private let signatureVecteur = "KVvqj9uJbv0TlFHRiKAk4amTyQex6Ez-ImuK-SknL_TDnee_es2q_MEpHuDXMncKWhGi8DUb4D_q5C7i5EOPAA"

private func identiteDe(_ cle: Chiffrement.Identite) -> String { Chiffrement.Identites.exporter(cle.publique) }

private func chefEtCle() -> (String, Chiffrement.Identite) { (FabriqueCharte.chef, Chiffrement.Identite.generer()) }

/// Charte signée (JSON brut + signature) pour les tests de garde.
private func signeeBase(version: Int, chef cle: Chiffrement.Identite, reseau: String = FabriqueCharte.reseau)
    async throws -> CharteSignee
{
    let brut = FabriqueCharte.charte(
        version: version, chefs: [FabriqueCharte.chef], par: FabriqueCharte.chef,
        membres: [FabriqueCharte.membre(FabriqueCharte.chef, .pair, cle)], reseau: reseau)
    return try await FabriqueCharte.signer(brut, par: cle)
}

struct CharteReseauTests {
    @Test func uneCharteValideSeLitEtExposeSesChamps() throws {
        let (chef, cle) = chefEtCle()
        let brut = FabriqueCharte.base(
            chef: cle, serveur: Chiffrement.Identite.generer(), pair: Chiffrement.Identite.generer())
        let c = try CharteReseau(brut: brut)
        #expect(c.reseau == FabriqueCharte.reseau)
        #expect(c.version == 1)
        #expect(c.estChef(chef))
        #expect(c.membre(FabriqueCharte.serveur)?.sorte == .serveur)
        #expect(c.membre(FabriqueCharte.pair)?.droits == .aucun)
    }

    @Test func uneCoherenceCasseeEstRefusee() throws {
        let cle = Chiffrement.Identite.generer()
        let chefServeur = FabriqueCharte.charte(
            version: 1, chefs: [FabriqueCharte.serveur], par: FabriqueCharte.serveur,
            membres: [FabriqueCharte.membre(FabriqueCharte.serveur, .serveur, cle)])
        #expect(throws: ErreurReseau.self) { try CharteReseau(brut: chefServeur) }
        let signataireHorsChefs = FabriqueCharte.charte(
            version: 1, chefs: [FabriqueCharte.chef], par: FabriqueCharte.pair,
            membres: [
                FabriqueCharte.membre(FabriqueCharte.chef, .pair, cle),
                FabriqueCharte.membre(FabriqueCharte.pair, .pair, cle),
            ])
        #expect(throws: ErreurReseau.self) { try CharteReseau(brut: signataireHorsChefs) }
    }

    @Test func unTexteIllisibleEstRefuse() {
        #expect(throws: ErreurReseau.self) { try CharteReseau(texte: "{pas du json") }
    }

    @Test func lesVecteursTsSontVerifiesParLaGenese() throws {
        let c = try #require(SignatureReseau.verifier(CharteSignee(texte: texteVecteur, signature: signatureVecteur)))
        #expect(c.reseau == "5e6f7a8b9c0d")
        #expect(c.version == 3)
        #expect(c.chefs == ["a1b2c3d4e5f6"])
        #expect(c.membres.count == 3)
        #expect(c.membre("9a8b7c6d5e4f")?.invite?.machines == ["0f1e2d3c4b5a"])
        #expect(c.membre("9a8b7c6d5e4f")?.invite?.part5h == 25)
    }

    @Test func unTexteAltereEstRefuse() {
        let altere = texteVecteur.replacingOccurrences(of: "Reseau de test", with: "Reseau pirate")
        #expect(SignatureReseau.verifier(CharteSignee(texte: altere, signature: signatureVecteur)) == nil)
    }

    @Test func uneSignatureAlteréeEstRefusee() {
        let premier = signatureVecteur.first == "A" ? "B" : "A"
        let altere = premier + signatureVecteur.dropFirst()
        #expect(SignatureReseau.verifier(CharteSignee(texte: texteVecteur, signature: altere)) == nil)
    }

    @Test func uneCharteSigneeParNousSeVerifie() async throws {
        let cle = Chiffrement.Identite.generer()
        let signee = try await signeeBase(version: 1, chef: cle)
        #expect(SignatureReseau.verifier(signee) != nil)
    }

    @Test func digneRefuseUneVersionPlusAncienne() async throws {
        let cle = Chiffrement.Identite.generer()
        let gardee = try await signeeBase(version: 3, chef: cle)
        let recue = try await signeeBase(version: 2, chef: cle)
        #expect(SignatureReseau.digne(recue: recue, gardee: gardee) == nil)
    }

    @Test func digneRefuseUnAutreReseau() async throws {
        let cle = Chiffrement.Identite.generer()
        let gardee = try await signeeBase(version: 1, chef: cle)
        let recue = try await signeeBase(version: 2, chef: cle, reseau: "aaaaaaaaaaaa")
        #expect(SignatureReseau.digne(recue: recue, gardee: gardee) == nil)
    }

    @Test func digneAccepteUneSuccessionSigneeParUnChefDeLaGardee() async throws {
        let cle = Chiffrement.Identite.generer()
        let gardee = try await signeeBase(version: 1, chef: cle)
        let recue = try await signeeBase(version: 2, chef: cle)
        #expect(SignatureReseau.digne(recue: recue, gardee: gardee)?.version == 2)
    }

    @Test func digneRefuseUneSuccessionSigneeParUnNonChefDeLaGardee() async throws {
        let cle = Chiffrement.Identite.generer()
        let gardee = try await signeeBase(version: 1, chef: cle)
        let intrus = Chiffrement.Identite.generer()
        let brut = FabriqueCharte.charte(
            version: 2, chefs: [FabriqueCharte.chef, FabriqueCharte.pair], par: FabriqueCharte.pair,
            membres: [
                FabriqueCharte.membre(FabriqueCharte.chef, .pair, cle),
                FabriqueCharte.membre(FabriqueCharte.pair, .pair, intrus),
            ])
        let recue = try await FabriqueCharte.signer(brut, par: intrus)
        #expect(SignatureReseau.digne(recue: recue, gardee: gardee) == nil)
    }

    @Test func sansGardeeLaGeneseFaitFoi() async throws {
        let cle = Chiffrement.Identite.generer()
        let signee = try await signeeBase(version: 1, chef: cle)
        #expect(SignatureReseau.digne(recue: signee, gardee: nil) != nil)
        let altere = CharteSignee(texte: signee.texte + " ", signature: signee.signature)
        #expect(SignatureReseau.digne(recue: altere, gardee: nil) == nil)
    }

    @Test func estChefDigneExigeUnChefAvecSaPropreIdentite() throws {
        let cle = Chiffrement.Identite.generer()
        let brut = FabriqueCharte.charte(
            version: 1, chefs: [FabriqueCharte.chef], par: FabriqueCharte.chef,
            membres: [FabriqueCharte.membre(FabriqueCharte.chef, .pair, cle)])
        let c = try CharteReseau(brut: brut)
        #expect(SignatureReseau.estChefDigne(c, moi: FabriqueCharte.chef, identiteMoi: identiteDe(cle)))
        #expect(
            !SignatureReseau.estChefDigne(
                c, moi: FabriqueCharte.chef, identiteMoi: identiteDe(Chiffrement.Identite.generer())))
        #expect(!SignatureReseau.estChefDigne(c, moi: FabriqueCharte.pair, identiteMoi: identiteDe(cle)))
    }
}
