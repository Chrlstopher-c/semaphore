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

/// Un morceau de la voix de la tour : PCM 24 kHz mono (transport direct), ou le MP3 entier (canal chiffré, relais).
public enum MorceauSynthese: Sendable {
    case pcm(Data)
    case mp3(Data)
}

/// Les octets d'une réponse en cours, passés d'une tâche à l'autre (lus par une seule à la fois).
private struct OctetsFlux: @unchecked Sendable {
    let valeur: URLSession.AsyncBytes
}

public final class ClientRelais: Sendable {
    public let adresse: URL
    private let jeton: String
    private let session: URLSession
    /// Les terminaux restent ouverts des heures, parfois muets : pas de délai d'inactivité de 40 s.
    public let sessionTerminal: URLSession
    /// Transport « par l'aiguilleur » : chaque requête, le flux et le terminal passent dans le canal chiffré vers le
    /// nœud, avec les mêmes messages que le WebSocket direct. nil : transport direct (HTTP et WebSocket).
    public let aiguilleur: ClientAiguilleur?

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
        let type = requete.value(forHTTPHeaderField: "Content-Type")
        do {
            let r = try await envoyerParCanal(canal, requete.httpMethod ?? "GET", chemin, donnees, type)
            let octets = r.codage == "base64" ? (Data(base64Encoded: r.corps) ?? Data()) : Data(r.corps.utf8)
            let entete = ["Content-Type": r.type ?? "application/json"]
            guard let http = HTTPURLResponse(url: url, statusCode: r.statut, httpVersion: nil, headerFields: entete)
            else { throw ErreurRelais.illisible("réponse du canal") }
            return (octets, http)
        } catch let e as ErreurRelais {
            throw e
        } catch {
            throw ErreurRelais.injoignable("aiguilleur : \(error.localizedDescription)")
        }
    }

    /// Le JSON part en texte, tout autre corps (fichier) part en base64 avec son type.
    private static func envoyerParCanal(_ canal: ClientAiguilleur, _ methode: String, _ chemin: String,
                                        _ donnees: Data?, _ type: String?) async throws -> ReponseRequete {
        guard let donnees, let type, !estTexte(type) else {
            let corps = donnees.flatMap { String(data: $0, encoding: .utf8) }
            return try await canal.requete(methode: methode, chemin: chemin, corps: corps, delai: delai(chemin))
        }
        return try await canal.requeteOctets(methode: methode, chemin: chemin, corps: donnees, type: type)
    }

    /// Le long-poll du relais rend au plus à 30 s : sa réponse doit pouvoir arriver avant le délai du canal.
    private static func delai(_ chemin: String) -> Duration? {
        chemin.hasPrefix("/api/attente") ? .seconds(40) : nil
    }

    private static func estTexte(_ type: String) -> Bool {
        type.hasPrefix("application/json") || type.hasPrefix("text/")
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

    /// Mode vocal : une phrase → son audio (MP3) synthétisé par la machine du réseau qui a une voix.
    public func synthese(_ texte: String) async throws -> Data {
        struct Corps: Encodable { let texte: String }
        var requete = try requete("POST", "/api/voix")
        requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requete.httpBody = try JSONEncoder().encode(Corps(texte: texte))
        requete.timeoutInterval = 15
        let (donnees, reponse) = try await transferer(requete)
        try verifier(donnees, reponse)
        return donnees
    }

    /// Mode vocal en flux : la tour livre la phrase au fil de sa génération (transport direct : PCM 24 kHz mono,
    /// audio/L16). Par le canal chiffré, ou relayée à un pair, c'est le MP3 entier, comme avant.
    public func syntheseFlux(_ texte: String) async throws -> AsyncThrowingStream<MorceauSynthese, Error> {
        guard aiguilleur == nil else {
            let mp3 = try await synthese(texte)
            return AsyncThrowingStream { suite in
                suite.yield(.mp3(mp3))
                suite.finish()
            }
        }
        struct Corps: Encodable { let texte: String }
        var requete = try requete("POST", "/api/voix?flux=1")
        requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requete.httpBody = try JSONEncoder().encode(Corps(texte: texte))
        requete.timeoutInterval = 15
        let (octets, reponse) = try await ouvrirFlux(requete)
        let statut = (reponse as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statut) else {
            var corps = Data()
            for try await octet in octets.valeur { corps.append(octet) }
            try verifier(corps, reponse)
            throw ErreurRelais.refus(statut, "erreur \(statut)")
        }
        let pcm = (reponse as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("audio/L16") ?? false
        let flux: AsyncThrowingStream<MorceauSynthese, Error> = AsyncThrowingStream { suite in
            let tache = Task {
                do {
                    try await Self.relayer(octets, pcm: pcm, vers: suite)
                    suite.finish()
                } catch {
                    suite.finish(throwing: ErreurRelais.injoignable(error.localizedDescription))
                }
            }
            suite.onTermination = { _ in tache.cancel() }
        }
        return flux
    }

    /// Le transport direct rend la réponse dès ses en-têtes ; ses octets sont lus ensuite, morceau par morceau.
    private func ouvrirFlux(_ requete: URLRequest) async throws -> (OctetsFlux, URLResponse) {
        do {
            let (octets, reponse) = try await session.bytes(for: requete)
            return (OctetsFlux(valeur: octets), reponse)
        } catch {
            throw ErreurRelais.injoignable(error.localizedDescription)
        }
    }

    /// PCM : un morceau tous les 2 Ko au plus (≈ 40 ms d'audio) ; MP3 : le corps entier, une fois reçu.
    private static func relayer(
        _ octets: OctetsFlux, pcm: Bool, vers suite: AsyncThrowingStream<MorceauSynthese, Error>.Continuation
    ) async throws {
        var lot = Data()
        for try await octet in octets.valeur {
            lot.append(octet)
            if pcm, lot.count >= 2048 {
                suite.yield(.pcm(lot))
                lot = Data()
            }
        }
        guard !lot.isEmpty else { return }
        suite.yield(pcm ? .pcm(lot) : .mp3(lot))
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
