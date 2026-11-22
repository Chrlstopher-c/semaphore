import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Responsabilité : le transport vers l'aiguilleur — appairage par code (POST), lien sortant WebSocket `/aiguilleur`
// authentifié par le jeton de membre. Le protocole (messages, canaux) vit dans `ProtocoleAiguilleur` ; ici, seulement
// l'acheminement. Une connexion par membre : l'aiguilleur remplace l'ancienne (fermeture 4409).

enum LienAiguilleur {
    struct Appairage: Equatable, Sendable {
        let id: String
        let jeton: String
    }

    /// Appairage d'un appareil par code : `POST /api/membres/appairer` ; le code est à usage unique, 10 minutes.
    static func appairer(adresse: URL, code: String, nom: String, cle: String) async throws -> Appairage {
        var requete = URLRequest(url: adresse.appendingPathComponent("api/membres/appairer"))
        requete.httpMethod = "POST"
        requete.setValue("application/json", forHTTPHeaderField: "content-type")
        let corps: [String: String] = ["code": code, "nom": nom, "genre": "appareil", "cle": cle]
        requete.httpBody = try JSONSerialization.data(withJSONObject: corps)
        let (donnees, reponse) = try await URLSession.shared.data(for: requete)
        guard let http = reponse as? HTTPURLResponse, http.statusCode == 200 else {
            throw ErreurChiffrement("appairage refusé")
        }
        guard let objet = try JSONSerialization.jsonObject(with: donnees) as? [String: Any],
              let id = objet["id"] as? String, let jeton = objet["jeton"] as? String else {
            throw ErreurChiffrement("réponse d'appairage illisible")
        }
        return Appairage(id: id, jeton: jeton)
    }

    /// Ouvre le lien sortant : https devient wss, http devient ws ; le jeton part en `Authorization: Bearer`.
    static func ouvrir(adresse: URL, jeton: String) throws -> URLSessionWebSocketTask {
        guard var composants = URLComponents(url: adresse, resolvingAgainstBaseURL: false) else {
            throw ErreurChiffrement("adresse de l'aiguilleur illisible")
        }
        composants.scheme = composants.scheme == "https" ? "wss" : "ws"
        composants.path = "/aiguilleur"
        guard let url = composants.url else { throw ErreurChiffrement("adresse du lien illisible") }
        var requete = URLRequest(url: url)
        requete.setValue("Bearer \(jeton)", forHTTPHeaderField: "Authorization")
        let tache = URLSession.shared.webSocketTask(with: requete)
        tache.resume()
        return tache
    }

    static func envoyer(
        _ message: ProtocoleAiguilleur.VersAiguilleur, sur tache: URLSessionWebSocketTask
    ) async throws {
        try await tache.send(.string(try ProtocoleAiguilleur.encoder(message)))
    }

    /// Un message de l'aiguilleur, ou une erreur s'il est hors protocole ou si le lien est coupé.
    static func recevoir(sur tache: URLSessionWebSocketTask) async throws -> ProtocoleAiguilleur.DeAiguilleur {
        switch try await tache.receive() {
        case let .string(texte): return try ProtocoleAiguilleur.decoderDeAiguilleur(texte)
        case .data: throw ErreurChiffrement("aiguilleur : trame binaire refusée")
        @unknown default: throw ErreurChiffrement("aiguilleur : trame inconnue")
        }
    }
}
