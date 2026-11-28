// Les appels HTTP au serveur Lueur, par le tunnel HTTPS (Wi-Fi comme 4G). Le Pi attend jusqu'à 12 s que le ruban soit
// joint avant de répondre à une commande : le délai (16 s) doit dépasser cette attente.
#if canImport(UIKit)
import Foundation
import LueurNoyau
import os

enum PanneLiaison: Error {
    case sansAdresse
    case reponse(Int)
    /// Le Pi a refusé (instructions invalides…) : son message.
    case refus(String)
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

    // MARK: - Routines et leurs instructions

    func routines() async throws -> [Routine] {
        try await charger([Routine].self, requete(chemin: "/api/routines"))
    }

    func scenarios() async throws -> [Scenario] {
        try await charger([Scenario].self, requete(chemin: "/api/scenarios"))
    }

    func ecrire(_ scenario: Scenario) async throws {
        try await appeler("PUT", "/api/scenarios/\(scenario.id)", corps: scenario.corps)
    }

    func ecrire(_ routine: Routine) async throws {
        try await appeler("PUT", "/api/routines/\(routine.id)", corps: routine.corps)
    }

    func supprimerRoutine(_ id: String) async throws {
        try await appeler("DELETE", "/api/routines/\(id)")
    }

    func supprimerScenario(_ id: String) async throws {
        try await appeler("DELETE", "/api/scenarios/\(id)")
    }

    /// Joue un scénario plafonné (les essais à 30 %, comme convenu avec Chris).
    func jouer(_ id: String, plafond: Int) async throws {
        let corps = try JSONSerialization.data(withJSONObject: ["max_brightness": plafond])
        try await appeler("POST", "/api/scenarios/\(id)/play", corps: corps)
    }

    func arreter() async throws {
        try await appeler("POST", "/api/playback/stop", corps: Data("{}".utf8))
    }

    private func appeler(_ methode: String, _ chemin: String, corps: Data? = nil) async throws {
        var demande = try requete(chemin: chemin)
        demande.httpMethod = methode
        if let corps {
            demande.setValue("application/json", forHTTPHeaderField: "Content-Type")
            demande.httpBody = corps
        }
        let (donnees, reponse) = try await session.data(for: demande)
        let code = (reponse as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let refus = (try? JSONDecoder().decode([String: String].self, from: donnees))?["error"]
            journal.error("\(methode, privacy: .public) \(chemin, privacy: .public) : \(code)")
            throw PanneLiaison.refus(refus ?? "erreur \(code)")
        }
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
