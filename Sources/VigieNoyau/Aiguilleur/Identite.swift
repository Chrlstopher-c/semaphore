import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// Responsabilité : identité d'un membre du réseau — X25519 (échange) et Ed25519 (signature), export, empreinte.
// Miroir de `commun/chiffrement/identite.ts`. L'export privé contient des secrets : il ne quitte jamais l'appareil.

extension Chiffrement {
    /// Identité publique : 32 octets X25519 puis 32 octets Ed25519, soit 86 caractères en base64url.
    public struct IdentitePublique: Equatable, Sendable {
        let dh: Data
        let signature: Data

        var octets: Data { dh + signature }
    }

    /// Identité complète : les clés privées ne sortent pas de cette structure sans export explicite.
    /// Clés CryptoKit immuables (`let` seulement) : sûres à passer d'un acteur à l'autre. swift-crypto ne les
    /// déclare pas Sendable sous Linux, d'où `@unchecked`.
    public struct Identite: @unchecked Sendable {
        let publique: IdentitePublique
        let dhPrivee: Curve25519.KeyAgreement.PrivateKey
        let signaturePrivee: Curve25519.Signing.PrivateKey

        static func generer() -> Identite {
            let dh = Curve25519.KeyAgreement.PrivateKey()
            let signe = Curve25519.Signing.PrivateKey()
            let publique = IdentitePublique(
                dh: dh.publicKey.rawRepresentation, signature: signe.publicKey.rawRepresentation
            )
            return Identite(publique: publique, dhPrivee: dh, signaturePrivee: signe)
        }

        /// Identité à partir de graines de 32 octets : seule voie déterministe, utilisée par les vecteurs croisés.
        static func depuisGraines(dh: Data, signature: Data) throws -> Identite {
            let dhPrivee = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: dh)
            let signaturePrivee = try Curve25519.Signing.PrivateKey(rawRepresentation: signature)
            let publique = IdentitePublique(dh: dhPrivee.publicKey.rawRepresentation,
                                            signature: signaturePrivee.publicKey.rawRepresentation)
            return Identite(publique: publique, dhPrivee: dhPrivee, signaturePrivee: signaturePrivee)
        }
    }

    public enum Identites {
        private static let premierEd25519 = "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed"

        public static func exporter(_ id: IdentitePublique) -> String {
            Octets.versBase64url(id.octets)
        }

        /// Valide la forme : 64 octets, Ed25519 canonique (y < p), clés acceptées par les primitives.
        public static func importer(_ texte: String) throws -> IdentitePublique {
            let octets = try Octets.depuisBase64url(texte, longueur: 2 * tailleCleDh)
            let id = IdentitePublique(dh: Data(octets.prefix(tailleCleDh)), signature: Data(octets.suffix(tailleCleDh)))
            guard signatureCanonique(id.signature) else { throw ErreurChiffrement("clé Ed25519 non canonique") }
            do {
                _ = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: id.dh)
                _ = try Curve25519.Signing.PublicKey(rawRepresentation: id.signature)
            } catch {
                throw ErreurChiffrement("clé publique refusée : \(error)")
            }
            return id
        }

        /// Empreinte SHA-256 : 16 groupes de 4 caractères hexadécimaux, lue des deux côtés à l'appairage.
        public static func empreinte(_ id: IdentitePublique) -> String {
            let hache = SHA256.hash(data: id.octets)
            let hex = hache.map { String(format: "%02X", $0) }.joined()
            var groupes: [String] = []
            var debut = hex.startIndex
            while debut < hex.endIndex {
                let fin = hex.index(debut, offsetBy: 4)
                groupes.append(String(hex[debut..<fin]))
                debut = fin
            }
            return groupes.joined(separator: " ")
        }

        /// Ordre des octets little-endian : y < p ⇔ l'entier lu sans le bit de signe est inférieur à p.
        static func signatureCanonique(_ cle: Data) -> Bool {
            var octets = Array(cle.prefix(tailleCleDh))
            guard octets.count == tailleCleDh else { return false }
            octets[31] &= 0x7f
            let p = [UInt8](Data(hexOctets: premierEd25519).reversed())
            for k in stride(from: 31, through: 0, by: -1) where octets[k] != p[k] {
                return octets[k] < p[k]
            }
            return false
        }
    }
}

private extension Data {
    init(hexOctets texte: String) {
        var sortie = Data()
        var index = texte.startIndex
        while index < texte.endIndex {
            let fin = texte.index(index, offsetBy: 2)
            sortie.append(UInt8(texte[index..<fin], radix: 16) ?? 0)
            index = fin
        }
        self = sortie
    }
}
