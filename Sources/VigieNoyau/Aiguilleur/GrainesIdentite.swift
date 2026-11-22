import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// Responsabilité : les graines de l'identité de l'appareil — 64 octets que l'appli garde ; l'identité (X25519 et
// Ed25519) et son empreinte s'en déduisent. Les graines ne quittent pas l'appli.

/// Graines de l'identité : 32 octets pour l'échange (X25519), 32 octets pour la signature (Ed25519).
public struct GrainesIdentite: Codable, Sendable, Equatable {
    public let dh: Data
    public let signature: Data

    public init(dh: Data, signature: Data) {
        self.dh = dh
        self.signature = signature
    }

    /// Graines neuves, tirées au hasard par le système.
    public static func generer() -> GrainesIdentite {
        let identite = Chiffrement.Identite.generer()
        return GrainesIdentite(
            dh: identite.dhPrivee.rawRepresentation, signature: identite.signaturePrivee.rawRepresentation
        )
    }

    /// L'identité complète déduite des graines ; une graine de mauvaise taille lève une erreur.
    public func identite() throws -> Chiffrement.Identite {
        try Chiffrement.Identite.depuisGraines(dh: dh, signature: signature)
    }

    /// Empreinte de l'identité publique, lue des deux côtés à l'appairage. Vide si les graines sont illisibles,
    /// auquel cas `identite()` a déjà levé son erreur à l'appairage.
    public var empreinte: String {
        guard let identite = try? identite() else { return "" }
        return Chiffrement.Identites.empreinte(identite.publique)
    }
}
