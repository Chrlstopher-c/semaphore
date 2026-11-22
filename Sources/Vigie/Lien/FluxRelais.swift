// Le flux temps réel du relais : un WebSocket sur `/api/flux`, chaque trame décodée en `MessageClient`.
// Ne se reconnecte pas : c'est le modèle qui relit l'état puis rouvre le flux. Fichier non isolé : aucune closure
// de rappel ne hérite de l'isolation du MainActor (piège du skill swift-ios).
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

public enum EvenementFlux: Sendable, Equatable {
    /// Un pong a répondu : la liaison est bien établie (répété à chaque ping, sans effet après le premier).
    case ouvert
    case message(MessageClient)
    /// La liaison est tombée ; le flux se termine juste après.
    case ferme(String)
}

/// Un socket ouvert sur `/api/flux`. `evenements` se termine à la coupure ; l'arrêt de la lecture ferme le socket.
public final class FluxRelais: @unchecked Sendable {
    // `@unchecked` : la tâche WebSocket n'est touchée que par cette classe, et URLSession sérialise ses appels.
    public let evenements: AsyncStream<EvenementFlux>
    private let tache: URLSessionWebSocketTask
    private let entree: AsyncStream<EvenementFlux>.Continuation

    public init(client: ClientRelais) throws {
        let requete = try client.requeteFlux()
        let tache = client.sessionTerminal.webSocketTask(with: requete)
        let (flux, entree) = AsyncStream.makeStream(of: EvenementFlux.self)
        self.tache = tache
        self.evenements = flux
        self.entree = entree
        entree.onTermination = { @Sendable [weak self] _ in self?.tache.cancel(with: .goingAway, reason: nil) }
    }

    /// Ouvre le socket, lit les trames et envoie les pings (un tout de suite, puis toutes les 25 s).
    public func ouvrir() {
        tache.resume()
        Task { await lire() }
        Task { await pinguer() }
    }

    public func fermer() {
        tache.cancel(with: .goingAway, reason: nil)
        entree.finish()
    }

    private func lire() async {
        while true {
            do {
                let trame = try await tache.receive()
                if let message = Self.decoder(trame) { entree.yield(.message(message)) }
            } catch {
                Trace.info("flux", "liaison coupée (\(error.localizedDescription))")
                entree.yield(.ferme(error.localizedDescription))
                entree.finish()
                return
            }
        }
    }

    /// Un ping par intervalle tant que la tâche tourne. Le pong sans erreur signale que la liaison vit.
    private func pinguer() async {
        while tache.state == .running {
            sonder()
            try? await Task.sleep(nanoseconds: LiaisonRelais.pingSecondes * 1_000_000_000)
        }
    }

    private func sonder() {
        tache.sendPing { [entree] erreur in
            if let erreur {
                Trace.detail("flux", "ping sans pong (\(erreur.localizedDescription))")
            } else {
                entree.yield(.ouvert)
            }
        }
    }

    /// Décode une trame texte ou binaire ; une trame illisible est écartée sans couper le flux.
    static func decoder(_ trame: URLSessionWebSocketTask.Message) -> MessageClient? {
        let donnees: Data
        switch trame {
        case .string(let texte): donnees = Data(texte.utf8)
        case .data(let brut): donnees = brut
        @unknown default: return nil
        }
        do {
            return try JSONDecoder().decode(MessageClient.self, from: donnees)
        } catch {
            Trace.erreur("flux", "trame illisible", error)
            return nil
        }
    }
}
#endif
