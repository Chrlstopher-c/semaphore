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
        case .injoignable(let raison): return "Nœud injoignable : \(raison)"
        case .nonConnecte: return "Connexion expirée : reconnecte-toi dans les réglages."
        case .refus(_, let message): return message
        // Le détail technique part au journal (Trace), jamais à l'écran.
        case .illisible: return "Réponse inattendue du nœud."
        }
    }
}

public final class ClientRelais: Sendable {
    public let adresse: URL
    private let jeton: String
    private let session: URLSession
    /// Les terminaux restent ouverts des heures, parfois muets : pas de délai d'inactivité de 40 s.
    public let sessionTerminal: URLSession
    /// Transport « par l'aiguilleur » : chaque requête passe dans le canal chiffré vers le nœud (aucun WebSocket de
    /// flux ni terminal par ce chemin : le modèle se rabat sur le long-poll). nil : transport direct (HTTP).
    public let aiguilleur: ClientAiguilleur?

    /// Le WebSocket `/api/flux` n'existe qu'en transport direct.
    public var fluxDisponible: Bool { aiguilleur == nil }

    public init(adresse: URL, jeton: String, aiguilleur: ClientAiguilleur? = nil) {
        self.adresse = adresse
        self.jeton = jeton
        self.aiguilleur = aiguilleur
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 40 // un long-poll du relais dure au plus 30 s
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
        let longue = URLSessionConfiguration.default
        longue.timeoutIntervalForRequest = 24 * 3600
        sessionTerminal = URLSession(configuration: longue)
    }

    /// Échange le mot de passe contre un jeton d'appareil (révocable côté relais).
    public static func connecter(adresse: URL, motDePasse: String) async throws -> String {
        let client = ClientRelais(adresse: adresse, jeton: "")
        struct Corps: Encodable { let motDePasse: String; let appareil: String }
        struct Reponse: Decodable { let jeton: String }
        let r: Reponse = try await client.envoyer("POST", Route.connexion, Corps(motDePasse: motDePasse, appareil: "iPhone (Vigie)"))
        return r.jeton
    }

    /// Échange un code d'appairage contre la clé de cet appareil (route ouverte, comme la connexion).
    public static func appairer(adresse: URL, code: String, nom: String) async throws -> String {
        let client = ClientRelais(adresse: adresse, jeton: "")
        let r: ReponseAppairage = try await client.envoyer("POST", Route.appairer, CorpsAppairage(code: code, nom: nom))
        return r.cle
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

    /// Contenu brut d'un fichier distant (aperçu, édition, partage).
    public func telecharger(_ chemin: String) async throws -> Data {
        let (donnees, reponse) = try await transferer(try requete("GET", chemin))
        try verifier(donnees, reponse)
        return donnees
    }

    /// Dépose un contenu brut (écrase le fichier distant). Pas de délai court : un gros envoi en 4G prend du temps.
    public func deposer(_ chemin: String, _ contenu: Data) async throws {
        var r = try requete("PUT", chemin)
        r.timeoutInterval = 600
        r.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (donnees, reponse) = try await transferer(r, envoi: contenu)
        try verifier(donnees, reponse)
    }

    /// Requête d'ouverture d'un terminal à distance : l'URL passe en ws(s), le jeton en en-tête.
    public func requeteTerminal(_ chemin: String) throws -> URLRequest {
        var r = try requete("GET", chemin)
        guard let url = r.url, var composants = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw ErreurRelais.illisible("adresse \(chemin)")
        }
        composants.scheme = composants.scheme == "https" ? "wss" : "ws"
        r.url = composants.url
        return r
    }

    /// Requête du flux temps réel (`/api/flux`) : ws(s), jeton en `Authorization: Bearer`.
    public func requeteFlux() throws -> URLRequest {
        var r = try requete("GET", Route.flux)
        guard let url = r.url, let flux = LiaisonRelais.adresseFlux(url) else {
            throw ErreurRelais.illisible("adresse du flux")
        }
        r.url = flux
        return r
    }

    private func requete(_ methode: String, _ chemin: String) throws -> URLRequest {
        guard let url = URL(string: chemin, relativeTo: adresse) else { throw ErreurRelais.illisible("adresse \(chemin)") }
        var requete = URLRequest(url: url)
        requete.httpMethod = methode
        if !jeton.isEmpty { requete.setValue("Bearer \(jeton)", forHTTPHeaderField: "Authorization") }
        return requete
    }

    private func transferer(_ requete: URLRequest, envoi: Data? = nil) async throws -> (Data, URLResponse) {
        if let aiguilleur { return try await Self.parCanal(aiguilleur, requete, envoi: envoi) }
        do {
            if let envoi { return try await session.upload(for: requete, from: envoi) }
            return try await session.data(for: requete)
        } catch {
            throw ErreurRelais.injoignable(error.localizedDescription)
        }
    }

    /// La même requête, rejouée dans le canal chiffré : chemin + requête, corps texte ; la réponse redevient HTTP.
    private static func parCanal(_ canal: ClientAiguilleur, _ requete: URLRequest,
                                 envoi: Data?) async throws -> (Data, URLResponse) {
        guard let url = requete.url else { throw ErreurRelais.illisible("adresse") }
        let chemin = url.path + (url.query.map { "?\($0)" } ?? "")
        let donnees = envoi ?? requete.httpBody
        let corps = donnees.flatMap { String(data: $0, encoding: .utf8) }
        do {
            let r = try await canal.requete(methode: requete.httpMethod ?? "GET", chemin: chemin, corps: corps)
            let entete = ["Content-Type": "application/json"]
            guard let http = HTTPURLResponse(url: url, statusCode: r.statut, httpVersion: nil, headerFields: entete)
            else { throw ErreurRelais.illisible("réponse du canal") }
            return (Data(r.corps.utf8), http)
        } catch let e as ErreurRelais {
            throw e
        } catch {
            throw ErreurRelais.injoignable("aiguilleur : \(error.localizedDescription)")
        }
    }

    private func envoyer<Corps: Encodable, T: Decodable>(_ methode: String, _ chemin: String, _ corps: Corps?) async throws -> T {
        var requete = try requete(methode, chemin)
        if let corps {
            requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
            requete.httpBody = try JSONEncoder().encode(corps)
        }
        let (donnees, reponse) = try await transferer(requete)
        return try decoder(donnees, reponse)
    }

    private func verifier(_ donnees: Data, _ reponse: URLResponse) throws {
        let statut = (reponse as? HTTPURLResponse)?.statusCode ?? 0
        if statut == 401 && !jeton.isEmpty { throw ErreurRelais.nonConnecte }
        guard (200..<300).contains(statut) else {
            let message = (try? JSONDecoder().decode(CorpsErreur.self, from: donnees))?.erreur ?? "erreur \(statut)"
            throw ErreurRelais.refus(statut, message)
        }
    }

    private func decoder<T: Decodable>(_ donnees: Data, _ reponse: URLResponse) throws -> T {
        try verifier(donnees, reponse)
        if T.self == Vide.self, let vide = Vide() as? T { return vide }
        do {
            return try JSONDecoder().decode(T.self, from: donnees)
        } catch {
            Trace.erreur("lien", "réponse indécodable (\(T.self))", error)
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
