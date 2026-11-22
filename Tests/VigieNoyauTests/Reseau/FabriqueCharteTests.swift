import Foundation

@testable import VigieNoyau

// Fabrique de chartes pour les tests du réseau : identités réelles (Ed25519 + X25519), identifiants de 12
// hexadécimaux, JSON brut construit à la main : les tests ne dépendent ni du client ni de l'édition testée.

/// Un signataire de test : une identité complète, sans réseau.
struct SignataireTest: Signataire {
    let membre: String
    let cle: Chiffrement.Identite

    func membreSignataire() async -> String { membre }

    func identiteSignataire() async -> String? { Chiffrement.Identites.exporter(cle.publique) }

    func signer(_ octets: Data) async throws -> Data { try cle.signaturePrivee.signature(for: octets) }
}

enum FabriqueCharte {
    static let reseau = "5e6f7a8b9c0d"
    static let chef = "a1b2c3d4e5f6"
    static let serveur = "0f1e2d3c4b5a"
    static let pair = "1111aaaa2222"
    static let invite = "9a8b7c6d5e4f"
    static let date = "2026-11-22T10:00:00.000Z"

    static func texteIdentite(_ cle: Chiffrement.Identite) -> String { Chiffrement.Identites.exporter(cle.publique) }

    static func membre(
        _ id: String, _ sorte: SorteMembre, _ cle: Chiffrement.Identite, droits: DroitsMembre = .tous,
        invite: ReglagesInvite? = nil
    ) -> ValeurJSON {
        var objet: [String: ValeurJSON] = [
            "id": .texte(id), "nom": .texte("Nom \(id)"), "sorte": .texte(sorte.rawValue),
            "identite": .texte(texteIdentite(cle)), "droits": droits.valeurJSON, "compte": .nul,
        ]
        if let invite { objet["invite"] = invite.valeurJSON }
        return .objet(objet)
    }

    /// Charte de base : le chef (pair), un serveur et un pair. Version 1, signée par le chef.
    static func base(chef cle: Chiffrement.Identite, serveur: Chiffrement.Identite, pair: Chiffrement.Identite)
        -> ValeurJSON
    {
        charte(
            version: 1, chefs: [chef], par: chef,
            membres: [
                membre(FabriqueCharte.chef, .pair, cle), membre(FabriqueCharte.serveur, .serveur, serveur),
                membre(FabriqueCharte.pair, .pair, pair, droits: .aucun),
            ])
    }

    static func charte(version: Int, chefs: [String], par: String, membres: [ValeurJSON], reseau: String = reseau)
        -> ValeurJSON
    {
        .objet([
            "format": .nombre(1), "reseau": .texte(reseau), "nom": .texte("Reseau test"),
            "version": .nombre(Double(version)), "chefs": .tableau(chefs.map { ValeurJSON.texte($0) }),
            "membres": .tableau(membres), "le": .texte(date), "par": .texte(par), "origine": .texte("creation"),
        ])
    }

    static func signer(_ brut: ValeurJSON, par cle: Chiffrement.Identite) async throws -> CharteSignee {
        let c = try CharteReseau(brut: brut)
        return try await SignatureReseau.signerCharte(c, par: SignataireTest(membre: c.par, cle: cle))
    }
}
