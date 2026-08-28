import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Le client HTTP du serveur Saily — l'unique porte REST entre l'app et la
/// prod.
///
/// `actor` pour la même raison que le `ClientEchoHub` d'EchoHub : le noyau ne
/// suppose aucun exécuteur, et l'adresse comme le jeton changent EN COURS DE
/// SESSION quand Chris édite les réglages, sans redémarrage.
///
/// Aucune méthode ne lance pour une erreur de transport : elles rendent une
/// `ErreurSaily` typée, journalisée au passage.
public actor ClientSaily {
    /// Large exprès : le chemin réel est iPhone → tunnel Cloudflare → Pi, dont
    /// un maillon en 4G.
    public static let delaiRequeteSecondes: TimeInterval = 20
    /// La sonde de santé doit échouer VITE : elle peint un état, elle n'attend
    /// pas une réponse utile.
    public static let delaiSondeSecondes: TimeInterval = 5
    /// Un téléversement de blob (vidéo) peut être lourd : on lui laisse de l'air.
    public static let delaiBlobSecondes: TimeInterval = 120

    private var reglages: ReglagesServeur
    private let session: URLSession
    private let sessionSonde: URLSession
    private let sessionBlob: URLSession

    public init(reglages: ReglagesServeur = .parDefaut) {
        self.reglages = reglages
        self.session = URLSession(configuration: Self.configuration(delai: Self.delaiRequeteSecondes))
        self.sessionSonde = URLSession(configuration: Self.configuration(delai: Self.delaiSondeSecondes))
        self.sessionBlob = URLSession(configuration: Self.configuration(delai: Self.delaiBlobSecondes))
    }

    private static func configuration(delai: TimeInterval) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = delai
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }

    public func configurer(_ nouveaux: ReglagesServeur) {
        reglages = nouveaux
        Journal.note("serveur reconfiguré sur \(nouveaux.adresse)")
    }

    public func reglagesCourants() -> ReglagesServeur { reglages }

    // MARK: - Construction de requêtes

    /// Construit une requête signée vers une route de l'API. `chemin` est donné
    /// SANS `/api` : le préfixe est ajouté ici, une seule fois.
    ///
    /// `☠` La requête (`?since=…`) est portée DU CÔTÉ requête, jamais concaténée
    /// au chemin : `appendingPathComponent` pourcent-encoderait le `?` et
    /// enverrait `items%3Fsince=` au serveur comme une route inconnue — un 404
    /// sur une route qui existe, l'heure de débogage la plus bête.
    public func requete(
        _ methode: String, _ chemin: String, corps: Data? = nil,
        typeContenu: String = "application/json"
    ) throws -> URLRequest {
        guard let base = URL(string: reglages.adresse), base.host != nil else {
            throw ErreurSaily.adresseInvalide(reglages.adresse)
        }
        guard let url = Self.url(base: base, chemin: chemin) else {
            throw ErreurSaily.adresseInvalide("\(reglages.adresse) + /api/\(chemin)")
        }
        var requete = URLRequest(url: url)
        requete.httpMethod = methode
        requete.httpBody = corps
        if corps != nil { requete.setValue(typeContenu, forHTTPHeaderField: "Content-Type") }
        if !reglages.jeton.isEmpty {
            requete.setValue("Bearer \(reglages.jeton)", forHTTPHeaderField: "Authorization")
        }
        return requete
    }

    static func url(base: URL, chemin: String) -> URL? {
        let morceaux = chemin.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var composants = URLComponents(
            url: base.appendingPathComponent("api").appendingPathComponent(String(morceaux[0])),
            resolvingAgainstBaseURL: false
        )
        if morceaux.count == 2 { composants?.percentEncodedQuery = String(morceaux[1]) }
        return composants?.url
    }

    /// L'URL du WebSocket : schéma `wss`/`ws` dérivé de l'adresse, chemin
    /// `/sync`, jeton en `?token=` (le seul canal d'auth d'un handshake WS).
    public func urlSync() -> URL? {
        guard let base = URL(string: reglages.adresse),
              var composants = URLComponents(url: base, resolvingAgainstBaseURL: false),
              let hote = composants.host else { return nil }
        _ = hote
        composants.scheme = (composants.scheme == "https") ? "wss" : "ws"
        let chemin = composants.path.hasSuffix("/") ? String(composants.path.dropLast()) : composants.path
        composants.path = chemin + "/sync"
        if !reglages.jeton.isEmpty {
            composants.queryItems = [URLQueryItem(name: "token", value: reglages.jeton)]
        }
        return composants.url
    }

    // MARK: - Exécution

    private func octets(
        _ methode: String, _ chemin: String, corps: Data?, typeContenu: String,
        session: URLSession
    ) async throws -> Data {
        let requete = try requete(methode, chemin, corps: corps, typeContenu: typeContenu)
        let donnees: Data
        let reponse: URLResponse
        do {
            (donnees, reponse) = try await session.data(for: requete)
        } catch {
            if ErreurSaily.vientDUneAnnulation(error) { throw ErreurSaily.annule }
            Journal.echec("requête \(methode) \(chemin) échouée : \(error.localizedDescription)")
            throw ErreurSaily.injoignable(error.localizedDescription)
        }
        try Self.verifierStatut(reponse, donnees: donnees, chemin: chemin)
        return donnees
    }

    static func verifierStatut(_ reponse: URLResponse, donnees: Data, chemin: String) throws {
        guard let http = reponse as? HTTPURLResponse else {
            throw ErreurSaily.reponseIllisible("réponse non HTTP sur \(chemin)")
        }
        guard !(200..<300).contains(http.statusCode) else { return }
        Journal.echec("statut \(http.statusCode) sur \(chemin)")
        throw ErreurSaily.depuisStatut(http.statusCode, donnees: donnees)
    }

    // MARK: - Items

    /// Le delta des items modifiés strictement après `since` (0 = tout,
    /// suppressions comprises).
    public func delta(depuis since: Int) async throws -> [Item] {
        let donnees = try await octets(
            "GET", "items?since=\(since)", corps: nil,
            typeContenu: "application/json", session: session
        )
        return try decoder(EnveloppeItems.self, donnees, chemin: "items").items
    }

    /// Pousse un item. Le serveur rend l'item persisté (avec ses horodatages
    /// autoritaires).
    public func upsert(_ item: ItemInput, clientId: String) async throws -> Item {
        let corps = try CodageJSON.encodeur().encode(RequeteUpsert(item: item, clientId: clientId))
        let donnees = try await octets(
            "POST", "items", corps: corps, typeContenu: "application/json", session: session
        )
        return try decoder(Item.self, donnees, chemin: "items")
    }

    /// Supprime logiquement un item. Le serveur rend `{ok:true}` : rien à
    /// décoder, seul le statut compte.
    public func supprimer(id: String, clientId: String) async throws {
        let echappe = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await octets(
            "DELETE", "items/\(echappe)?clientId=\(clientId)", corps: nil,
            typeContenu: "application/json", session: session
        )
    }

    // MARK: - Blobs

    /// Téléverse un blob (image/vidéo/fichier). Rend le nom à référencer dans un
    /// item et le type MIME retenu par le serveur.
    public func televerserBlob(
        octets contenu: Data, nomFichier: String, typeMime: String
    ) async throws -> ReponseBlob {
        var corps = CorpsMultipart()
        corps.fichier("file", nomFichier: nomFichier, typeMime: typeMime, octets: contenu)
        let donnees = try await self.octets(
            "POST", "blobs", corps: corps.terminer(), typeContenu: corps.typeContenu,
            session: sessionBlob
        )
        return try decoder(ReponseBlob.self, donnees, chemin: "blobs")
    }

    /// Récupère les octets d'un blob (auth exigée par l'API). Sert l'aperçu des
    /// images/vidéos dans l'inbox.
    public func blob(_ nom: String) async throws -> Data {
        let echappe = nom.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? nom
        return try await octets(
            "GET", "blobs/\(echappe)", corps: nil, typeContenu: "application/json",
            session: session
        )
    }

    // MARK: - Santé

    /// Le serveur répond-il ? Sonde `GET /health` (route publique, hors `/api`).
    /// Rend un `Result` typé : `injoignable`/`refuse`/illisible se distinguent,
    /// pour que « teste » dise QUOI réparer.
    public func sonder() async -> Result<SanteServeur, ErreurSaily> {
        guard let base = URL(string: reglages.adresse), base.host != nil else {
            return .failure(.adresseInvalide(reglages.adresse))
        }
        let requete = URLRequest(url: base.appendingPathComponent("health"))
        do {
            let (donnees, reponse) = try await sessionSonde.data(for: requete)
            guard let http = reponse as? HTTPURLResponse else {
                return .failure(.reponseIllisible("réponse non HTTP sur /health"))
            }
            guard (200..<300).contains(http.statusCode) else {
                return .failure(ErreurSaily.depuisStatut(http.statusCode, donnees: donnees))
            }
            let sante = try CodageJSON.decodeur().decode(SanteServeur.self, from: donnees)
            return .success(sante)
        } catch {
            if ErreurSaily.vientDUneAnnulation(error) { return .failure(.annule) }
            Journal.echec("sonde /health échouée : \(error.localizedDescription)")
            return .failure(.injoignable(error.localizedDescription))
        }
    }

    private func decoder<T: Decodable>(_ type: T.Type, _ donnees: Data, chemin: String) throws -> T {
        do {
            return try CodageJSON.decodeur().decode(T.self, from: donnees)
        } catch {
            Journal.echec("décodage \(T.self) échoué sur \(chemin) : \(error)")
            throw ErreurSaily.reponseIllisible(String(describing: error))
        }
    }
}

/// `GET /api/items` répond `{items: [...]}`.
struct EnveloppeItems: Decodable { let items: [Item] }

/// Le corps de `POST /api/items` : `{item, clientId}`.
struct RequeteUpsert: Encodable {
    let item: ItemInput
    let clientId: String
}

/// `POST /api/blobs` répond `{blob, mime}`.
public struct ReponseBlob: Decodable, Sendable, Equatable {
    public let blob: String
    public let mime: String
}

/// Ce que `GET /health` dit du serveur.
public struct SanteServeur: Decodable, Sendable, Equatable {
    public let ok: Bool
    public let service: String?
    public let time: Int?
}
