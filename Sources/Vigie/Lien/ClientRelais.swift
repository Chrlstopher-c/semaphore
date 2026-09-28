// Le client HTTP du relais ccremote v2 : jeton d'appareil en Bearer, JSON dans les deux sens, erreurs nommées.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

public enum ErreurRelais: Error, CustomStringConvertible {
    case injoignable(String)
    case nonConnecte
    case refus(Int, String)
    case illisible(String)

    public var description: String {
        switch self {
        case .injoignable(let raison): return "Relais injoignable (\(raison))"
        case .nonConnecte: return "Connexion expirée : reconnecte-toi dans les réglages."
        case .refus(_, let message): return message
        case .illisible(let raison): return "Réponse illisible (\(raison))"
        }
    }
}

public final class ClientRelais: Sendable {
    public let adresse: URL
    private let jeton: String
    private let session: URLSession

    public init(adresse: URL, jeton: String) {
        self.adresse = adresse
        self.jeton = jeton
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 40 // un long-poll du relais dure au plus 30 s
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    /// Échange le mot de passe contre un jeton d'appareil (révocable côté relais).
    public static func connecter(adresse: URL, motDePasse: String) async throws -> String {
        let client = ClientRelais(adresse: adresse, jeton: "")
        struct Corps: Encodable { let motDePasse: String; let appareil: String }
        struct Reponse: Decodable { let jeton: String }
        let r: Reponse = try await client.envoyer("POST", Route.connexion, Corps(motDePasse: motDePasse, appareil: "iPhone (Vigie)"))
        return r.jeton
    }

    public func lire<T: Decodable>(_ chemin: String) async throws -> T {
        try await envoyer("GET", chemin, Optional<Vide>.none)
    }

    @discardableResult
    public func ecrire<Corps: Encodable>(_ chemin: String, _ corps: Corps) async throws -> Vide {
        try await envoyer("POST", chemin, corps)
    }

    public func ouvrir(_ demande: DemandeOuverture) async throws -> Session {
        try await envoyer("POST", Route.sessions, demande)
    }

    private func envoyer<Corps: Encodable, T: Decodable>(_ methode: String, _ chemin: String, _ corps: Corps?) async throws -> T {
        guard let url = URL(string: chemin, relativeTo: adresse) else { throw ErreurRelais.illisible("adresse \(chemin)") }
        var requete = URLRequest(url: url)
        requete.httpMethod = methode
        if !jeton.isEmpty { requete.setValue("Bearer \(jeton)", forHTTPHeaderField: "Authorization") }
        if let corps {
            requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
            requete.httpBody = try JSONEncoder().encode(corps)
        }
        let (donnees, reponse): (Data, URLResponse)
        do {
            (donnees, reponse) = try await session.data(for: requete)
        } catch {
            throw ErreurRelais.injoignable(error.localizedDescription)
        }
        return try decoder(donnees, reponse)
    }

    private func decoder<T: Decodable>(_ donnees: Data, _ reponse: URLResponse) throws -> T {
        let statut = (reponse as? HTTPURLResponse)?.statusCode ?? 0
        if statut == 401 && !jeton.isEmpty { throw ErreurRelais.nonConnecte }
        guard (200..<300).contains(statut) else {
            let message = (try? JSONDecoder().decode(CorpsErreur.self, from: donnees))?.erreur ?? "erreur \(statut)"
            throw ErreurRelais.refus(statut, message)
        }
        if T.self == Vide.self, let vide = Vide() as? T { return vide }
        do {
            return try JSONDecoder().decode(T.self, from: donnees)
        } catch {
            throw ErreurRelais.illisible("\(error)")
        }
    }
}

private struct CorpsErreur: Decodable { let erreur: String }

/// Réponse sans contenu utile (écritures) : on ne vérifie que le statut.
public struct Vide: Codable, Sendable {
    public init() {}
}
#endif
