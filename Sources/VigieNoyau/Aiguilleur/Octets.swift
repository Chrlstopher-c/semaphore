import Foundation

// Responsabilité : octets sans ambiguïté — base64url, compteurs 64 bits, transcription à longueurs préfixées.
// Miroir exact de `commun/chiffrement/octets.ts` (Quart) : tout écart casse l'interopérabilité.

/// Erreur unique du chiffrement de bout en bout : un refus est toujours explicite.
struct ErreurChiffrement: Error, Equatable, CustomStringConvertible {
    let description: String

    init(_ message: String) {
        description = message
    }
}

/// Namespace du chiffrement de bout en bout (poignée, canal, identités), commun à l'aiguilleur et aux nœuds.
enum Chiffrement {
    static let tailleCompteur = 8
    static let tailleEtiquette = 16
    static let tailleCleDh = 32
    static let tailleSignature = 64

    /// Ensemble des octets d'une trame et d'une clé : ni ambigu ni dépendant de la plateforme.
    enum Octets {
        private static let alphabetBase64url = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

        static func versBase64url(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }

        static func depuisBase64url(_ texte: String, longueur: Int? = nil) throws -> Data {
            guard texte.allSatisfy({ alphabetBase64url.contains($0) }) else {
                throw ErreurChiffrement("base64url invalide")
            }
            let standard = texte.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let complet = standard + String(repeating: "=", count: (4 - standard.count % 4) % 4)
            guard let data = Data(base64Encoded: complet) else {
                throw ErreurChiffrement("base64url mal formé")
            }
            if let longueur, data.count != longueur {
                throw ErreurChiffrement("longueur \(data.count) au lieu de \(longueur)")
            }
            return data
        }

        /// Chaque morceau est précédé de sa longueur sur 4 octets (big-endian) : deux découpages ne collent jamais.
        static func transcription(_ morceaux: [Data]) -> Data {
            var sortie = Data()
            for morceau in morceaux {
                sortie.append(contentsOf: ueSur4(UInt32(morceau.count)))
                sortie.append(morceau)
            }
            return sortie
        }

        static func compteur(_ valeur: UInt64) -> Data {
            Data((0..<8).map { UInt8((valeur >> (56 - 8 * UInt64($0))) & 0xff) })
        }

        static func lireCompteur<D: DataProtocol>(_ data: D) -> UInt64 {
            data.prefix(tailleCompteur).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        }

        private static func ueSur4(_ valeur: UInt32) -> [UInt8] {
            (0..<4).map { UInt8((valeur >> (24 - 8 * UInt32($0))) & 0xff) }
        }
    }
}
