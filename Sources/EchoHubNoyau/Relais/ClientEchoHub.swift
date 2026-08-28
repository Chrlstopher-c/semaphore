import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Le client HTTP du relais — l'unique porte entre l'app et le PC.
///
/// `actor` pour la même raison que le `ClientRelais` de Sillon : le noyau ne
/// suppose aucun exécuteur, et l'adresse comme le jeton changent EN COURS DE
/// SESSION quand Chris édite les réglages, sans redémarrage.
///
/// Aucune méthode ne lance pour une erreur de transport : elles rendent une
/// `ErreurRelais` typée, journalisée au passage.
public actor ClientEchoHub {
    /// Le pire cas toléré pour une requête ordinaire. Large exprès : le chemin
    /// réel est iPhone → tunnel Cloudflare → Pi → PC, quatre maillons, dont un
    /// en 4G. Sillon a mesuré 0,21 à 1,29 s pour une simple sonde à travers ce
    /// tunnel, et a dû élargir deux fois ses délais pour cette raison exacte.
    public static let delaiRequeteSecondes: TimeInterval = 20
    /// La sonde de joignabilité, elle, doit échouer VITE : elle sert à peindre
    /// un état, pas à obtenir une réponse.
    public static let delaiSondeSecondes: TimeInterval = 5
    /// Une génération n'a pas de durée bornée connue. Le délai porte sur
    /// l'établissement, pas sur la traversée du flux.
    public static let delaiFluxSecondes: TimeInterval = 900

    private var reglages: ReglagesRelais
    private let session: URLSession
    private let sessionSonde: URLSession

    public init(reglages: ReglagesRelais = .parDefaut) {
        self.reglages = reglages
        self.session = URLSession(configuration: Self.configuration(delai: Self.delaiRequeteSecondes))
        self.sessionSonde = URLSession(configuration: Self.configuration(delai: Self.delaiSondeSecondes))
    }

    /// La configuration d'un flux de generation. Publique parce que
    /// `FluxGeneration` doit construire SA session : un delegue est une
    /// propriete de session, pas de requete, et deux flux concurrents ne
    /// doivent pas partager de collecteur.
    public static func configurationFlux() -> URLSessionConfiguration {
        configuration(delai: delaiFluxSecondes)
    }

    private static func configuration(delai: TimeInterval) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = delai
        // Un flux SSE ne doit jamais etre servi depuis un cache, et les reponses
        // de l'API changent a chaque token genere : le cache ne rendrait service
        // a personne et masquerait un relais mort derriere une reponse ancienne.
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }

    /// Change adresse et jeton en cours de session — c'est ce qu'appelle l'écran
    /// de réglages quand Chris passe du Wi-Fi de la maison à la 4G.
    public func configurer(_ nouveaux: ReglagesRelais) {
        reglages = nouveaux
        Journal.note("relais reconfiguré sur \(nouveaux.adresse)")
    }

    public func adresseCourante() -> String { reglages.adresse }

    // MARK: - Requêtes

    /// Construit une requête signée vers une route de l'API EchoHub.
    ///
    /// `chemin` est donné SANS `/api` : le préfixe est ajouté ici, une seule
    /// fois, parce que c'est une décision de transport. Le relais le transmet
    /// tel quel au PC, où nginx le retire avant FastAPI.
    public func requete(
        _ methode: String, _ chemin: String, corps: Data? = nil,
        typeContenu: String = "application/json"
    ) throws -> URLRequest {
        guard let base = URL(string: reglages.adresse), base.host != nil else {
            throw ErreurRelais.adresseInvalide(reglages.adresse)
        }
        guard let url = Self.url(base: base, chemin: chemin) else {
            throw ErreurRelais.adresseInvalide("\(reglages.adresse) + /api/\(chemin)")
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

    /// Assemble `base` + `/api/` + `chemin`, en gardant la requête (`?a=b`) DU
    /// CÔTÉ requête.
    ///
    /// `☠` `appendingPathComponent` traite ce qu'on lui donne comme un segment
    /// de CHEMIN : il pourcent-encode le `?`, et `…/conversations%3Farchivees=`
    /// part vers le serveur comme une route inconnue. Le symptôme serait un 404
    /// sur une route qui existe — l'heure de débogage la plus bête possible.
    static func url(base: URL, chemin: String) -> URL? {
        let morceaux = chemin.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var composants = URLComponents(
            url: base.appendingPathComponent("api").appendingPathComponent(String(morceaux[0])),
            resolvingAgainstBaseURL: false
        )
        if morceaux.count == 2 { composants?.percentEncodedQuery = String(morceaux[1]) }
        return composants?.url
    }

    /// GET/POST/PATCH/DELETE ordinaire, décodé dans le type attendu.
    public func lire<T: Decodable>(
        _ type: T.Type, _ methode: String, _ chemin: String, corps: Data? = nil,
        typeContenu: String = "application/json"
    ) async throws -> T {
        let donnees = try await octets(methode, chemin, corps: corps, typeContenu: typeContenu)
        do {
            return try CodageJSON.decodeur().decode(T.self, from: donnees)
        } catch {
            Journal.echec("décodage \(T.self) échoué sur \(chemin) : \(error)")
            throw ErreurRelais.reponseIllisible(String(describing: error))
        }
    }

    /// Lit une réponse SANS la conversion de clés du contrat.
    ///
    /// `☠` `JSONDecoder.keyDecodingStrategy` s'applique AUSSI aux clés d'un
    /// dictionnaire : décoder un plan de chargement par `CodageJSON` rendrait
    /// `couchesGpu` là où le serveur a écrit `couches_gpu`, et le réémettre
    /// produirait un corps que pydantic refuserait. Un aller-retour opaque doit
    /// rester opaque de bout en bout.
    public func lireOpaque(
        _ methode: String, _ chemin: String, corps: ValeurJSON? = nil
    ) async throws -> ValeurJSON {
        let encodes = try corps.map { try CodageOpaque.encodeur().encode($0) }
        let donnees = try await octets(methode, chemin, corps: encodes)
        do {
            return try CodageOpaque.decodeur().decode(ValeurJSON.self, from: donnees)
        } catch {
            Journal.echec("réponse opaque illisible sur \(chemin) : \(error)")
            throw ErreurRelais.reponseIllisible(String(describing: error))
        }
    }

    /// Même chose quand la réponse ne porte rien d'exploitable.
    public func executer(_ methode: String, _ chemin: String, corps: Data? = nil) async throws {
        _ = try await octets(methode, chemin, corps: corps)
    }

    private func octets(
        _ methode: String, _ chemin: String, corps: Data?,
        typeContenu: String = "application/json"
    ) async throws -> Data {
        let requete = try requete(methode, chemin, corps: corps, typeContenu: typeContenu)
        let donnees: Data
        let reponse: URLResponse
        do {
            (donnees, reponse) = try await session.data(for: requete)
        } catch {
            Journal.echec("requête \(methode) \(chemin) échouée : \(error.localizedDescription)")
            throw ErreurRelais.injoignable(error.localizedDescription)
        }
        try Self.verifierStatut(reponse, donnees: donnees, chemin: chemin)
        return donnees
    }

    /// Traduit un statut HTTP en `ErreurRelais`, en préférant TOUJOURS le
    /// message que le serveur a pris la peine d'écrire au libellé générique.
    ///
    /// La traduction elle-même vit dans `LectureRefus` : c'est la même pour une
    /// requête ordinaire et pour un flux refusé, et elle y est éprouvable sans
    /// réseau.
    static func verifierStatut(_ reponse: URLResponse, donnees: Data, chemin: String) throws {
        guard let http = reponse as? HTTPURLResponse else {
            throw ErreurRelais.reponseIllisible("réponse non HTTP sur \(chemin)")
        }
        guard !(200..<300).contains(http.statusCode) else { return }
        Journal.echec("statut \(http.statusCode) sur \(chemin)")
        throw LectureRefus.erreur(statut: http.statusCode, donnees: donnees)
    }

    // MARK: - Joignabilité

    /// Le relais répond-il ? Sonde `GET /sante` sur le relais lui-même — pas sur
    /// l'API du PC : c'est le relais qui sait, lui, si le PC répond, et il le
    /// dit dans sa réponse.
    /// `☠` Rend un `Result` et non un optionnel. Le `nil` d'avant écrasait trois
    /// réalités en une : relais injoignable, JETON REFUSÉ, réponse illisible.
    /// Au tout premier lancement — le moment où l'on colle un jeton, donc celui
    /// où l'on se trompe — un jeton mal collé affichait « Relais injoignable »
    /// et envoyait vérifier le tunnel et le PC, alors que le seul problème était
    /// le champ juste au-dessus.
    public func sonder() async -> Result<SanteRelais, ErreurRelais> {
        guard let base = URL(string: reglages.adresse), base.host != nil else {
            return .failure(.adresseInvalide(reglages.adresse))
        }
        var requete = URLRequest(url: base.appendingPathComponent("sante"))
        if !reglages.jeton.isEmpty {
            requete.setValue("Bearer \(reglages.jeton)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (donnees, reponse) = try await sessionSonde.data(for: requete)
            return Self.lireSante(donnees: donnees, reponse: reponse)
        } catch {
            Journal.echec("sonde du relais échouée : \(error.localizedDescription)")
            return .failure(.injoignable(error.localizedDescription))
        }
    }

    private static func lireSante(
        donnees: Data, reponse: URLResponse
    ) -> Result<SanteRelais, ErreurRelais> {
        guard let http = reponse as? HTTPURLResponse else {
            return .failure(.reponseIllisible("réponse non HTTP sur /sante"))
        }
        guard (200..<300).contains(http.statusCode) else {
            // Un 401 ou un 502 disparaissait ici sans trace — `idevicesyslog`
            // est la seule fenêtre de débogage sur un appareil sideloadé.
            Journal.echec("sonde /sante : statut \(http.statusCode)")
            return .failure(LectureRefus.erreur(statut: http.statusCode, donnees: donnees))
        }
        do {
            return .success(try CodageJSON.decodeur().decode(SanteRelais.self, from: donnees))
        } catch {
            Journal.echec("réponse de /sante illisible : \(error)")
            return .failure(.reponseIllisible(String(describing: error)))
        }
    }
}

/// Ce que le relais dit de lui-même et du PC derrière lui.
public struct SanteRelais: Sendable, Decodable, Equatable {
    public let ok: Bool
    /// EchoHub répond-il, vu du Pi ? C'est la seule machine bien placée pour le
    /// savoir : l'iPhone, lui, ne voit que le relais.
    public let echohub: Bool
    /// Ce que le PC a répondu la dernière fois qu'on lui a demandé, si on le
    /// sait. `nil` quand le relais n'a pas encore eu l'occasion de demander.
    public let detail: String?
}
