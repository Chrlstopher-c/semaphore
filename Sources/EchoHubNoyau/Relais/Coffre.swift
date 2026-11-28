import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Un secret du coffre echo-vault de la tour, sans sa valeur. `nom` est son identifiant.
///
/// Contrat : `echo-vault/src/http-server.ts`, joint par la route `/coffre/*` du relais du Pi.
public struct SecretCoffre: Sendable, Equatable, Identifiable, Decodable {
    public let nom: String
    public let genre: String
    public let note: String
    public let creeLe: Date
    public let modifieLe: Date

    public var id: String { nom }

    public init(nom: String, genre: String, note: String, creeLe: Date, modifieLe: Date) {
        self.nom = nom
        self.genre = genre
        self.note = note
        self.creeLe = creeLe
        self.modifieLe = modifieLe
    }

    enum CodingKeys: String, CodingKey {
        case nom = "name", genre = "kind", note, creeLe = "createdAt", modifieLe = "updatedAt"
    }

    /// Les dates arrivent en millisecondes depuis 1970 (`Date.now()` de Bun).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nom = try c.decode(String.self, forKey: .nom)
        genre = try c.decode(String.self, forKey: .genre)
        note = try c.decode(String.self, forKey: .note)
        creeLe = Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .creeLe) / 1000)
        modifieLe = Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .modifieLe) / 1000)
    }
}

/// Ce qu'une création ou une modification envoie. Un champ `nil` n'est pas envoyé, donc pas changé.
public struct EditionSecret: Sendable, Equatable, Encodable {
    public var nom: String?
    public var valeur: String?
    public var genre: String?
    public var note: String?

    public init(nom: String? = nil, valeur: String? = nil, genre: String? = nil, note: String? = nil) {
        self.nom = nom
        self.valeur = valeur
        self.genre = genre
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case nom = "name", valeur = "value", genre = "kind", note
    }
}

/// Les genres que le coffre connaît déjà (`echo-vault store --kind`).
public enum GenresSecret {
    public static let tous = ["secret", "token", "api-key", "password", "tunnel"]
}

extension ClientEchoHub {
    private struct ListeCoffre: Decodable { let secrets: [SecretCoffre] }
    private struct ValeurCoffre: Decodable { let value: String }

    public func secretsCoffre() async throws -> [SecretCoffre] {
        try Self.decoderCoffre(ListeCoffre.self, try await routeRelais("GET", "coffre/secrets")).secrets
    }

    /// La valeur en clair. À ne demander qu'au geste de Chris, après Face ID.
    public func valeurSecret(_ nom: String) async throws -> String {
        try Self.decoderCoffre(ValeurCoffre.self, try await routeRelais("GET", Self.cheminSecret(nom))).value
    }

    public func creerSecret(_ edition: EditionSecret) async throws {
        _ = try await routeRelais("POST", "coffre/secrets", corps: try JSONEncoder().encode(edition))
    }

    public func modifierSecret(_ nom: String, _ edition: EditionSecret) async throws {
        _ = try await routeRelais("PATCH", Self.cheminSecret(nom), corps: try JSONEncoder().encode(edition))
    }

    public func supprimerSecret(_ nom: String) async throws {
        _ = try await routeRelais("DELETE", Self.cheminSecret(nom))
    }

    /// Un nom peut contenir espace ou `/` : il est encodé en un seul segment.
    static func cheminSecret(_ nom: String) -> String {
        var permis = CharacterSet.urlPathAllowed
        permis.remove("/")
        return "coffre/secrets/" + (nom.addingPercentEncoding(withAllowedCharacters: permis) ?? nom)
    }

    private static func decoderCoffre<T: Decodable>(_ type: T.Type, _ donnees: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: donnees)
        } catch {
            throw ErreurRelais.reponseIllisible(String(describing: error))
        }
    }
}
