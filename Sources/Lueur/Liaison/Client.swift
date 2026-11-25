// Les appels HTTP au serveur Lueur, par le tunnel HTTPS (Wi-Fi comme 4G). Le Pi attend jusqu'à 12 s que le ruban soit
// joint avant de répondre à une commande : le délai (16 s) doit dépasser cette attente.
#if canImport(UIKit)
import Foundation
import LueurNoyau
import os

enum PanneLiaison: Error {
    case sansAdresse
    case reponse(Int)
}

struct Client: Sendable {
    private let journal = Logger(subsystem: "com.echo.labs", category: "lueur")
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 16
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    func etat() async throws -> EtatLumiere {
        try await charger(EtatLumiere.self, requete(chemin: "/api/state"))
    }

    func effets() async throws -> [Effet] {
        try await charger([Effet].self, requete(chemin: "/api/effects"))
    }

    func envoyer(_ commande: Commande) async throws -> ReponseAction {
        var demande = try requete(chemin: commande.chemin)
        demande.httpMethod = "POST"
        demande.setValue("application/json", forHTTPHeaderField: "Content-Type")
        demande.httpBody = commande.corps
        return try await charger(ReponseAction.self, demande)
    }

    private func requete(chemin: String) throws -> URLRequest {
        guard let base = Parametres.base else { throw PanneLiaison.sansAdresse }
        var demande = URLRequest(url: base.appending(path: chemin))
        if let cle = Parametres.cle { demande.setValue("Bearer \(cle)", forHTTPHeaderField: "Authorization") }
        return demande
    }

    private func charger<T: Decodable>(_ type: T.Type, _ demande: URLRequest) async throws -> T {
        do {
            let (donnees, reponse) = try await session.data(for: demande)
            let code = (reponse as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else { throw PanneLiaison.reponse(code) }
            return try JSONDecoder().decode(type, from: donnees)
        } catch {
            let chemin = demande.url?.path ?? "?"
            journal.error("\(chemin, privacy: .public) : \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
#endif
