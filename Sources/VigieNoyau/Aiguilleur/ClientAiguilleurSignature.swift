import Foundation

// Responsabilité : l'iPhone comme signataire du réseau — son identifiant de membre chez l'aiguilleur, son identité
// d'appairage, et la clé Ed25519 qui signe les chartes et les ordres. Aucune clé ne sort de l'appareil.
// La conformité `Signataire` est déclarée sur le type (ClientAiguilleur.swift) : Swift refuse `public` sur une
// extension qui la porte.

extension ClientAiguilleur {
    public func membreSignataire() async -> String { etat.membre }

    public func identiteSignataire() async -> String? { moi.map { Chiffrement.Identites.exporter($0.publique) } }

    public func signer(_ octets: Data) async throws -> Data {
        guard let moi else { throw ErreurAiguilleur("identité de l'appareil absente : appairage à refaire") }
        return try moi.signaturePrivee.signature(for: octets)
    }
}
