import Foundation

// Responsabilité : décodage tolérant du contrat — un champ facultatif qui ne colle pas devient absent, sans
// jamais faire échouer l'objet parent. Les nombres se lisent en `Double` puis se convertissent.

extension KeyedDecodingContainer {
    /// Un champ facultatif mal formé devient `nil` au lieu de faire échouer l'objet qui le porte.
    public func facultatif<T: Decodable>(_ type: T.Type, _ cle: Key) -> T? {
        try? decodeIfPresent(T.self, forKey: cle)
    }

    /// Un entier obligatoire, lu comme nombre JSON.
    public func entier(_ cle: Key) throws -> Int {
        let valeur = try decode(Double.self, forKey: cle)
        guard let entier = NombreJSON.entier(valeur) else {
            throw DecodingError.dataCorruptedError(forKey: cle, in: self, debugDescription: "entier attendu")
        }
        return entier
    }

    /// Un entier facultatif : absent ou mal formé donne `nil`.
    public func entierFacultatif(_ cle: Key) -> Int? {
        facultatif(Double.self, cle).flatMap(NombreJSON.entier)
    }
}

/// Un élément de liste : s'il ne se décode pas, il est écarté sans faire échouer la liste entière.
public struct Tolere<T: Decodable & Sendable>: Decodable, Sendable {
    public let valeur: T?

    public init(from decodeur: Decoder) throws {
        valeur = try? T(from: decodeur)
    }
}

public enum NombreJSON {
    /// Convertit un nombre JSON en entier ; `nil` pour un non-fini ou un nombre hors d'échelle.
    public static func entier(_ valeur: Double) -> Int? {
        guard valeur.isFinite, abs(valeur) < 1e15 else { return nil }
        return Int(valeur.rounded())
    }
}
