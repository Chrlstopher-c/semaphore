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
    private let vivacite = VivaciteLiaison()
    private var veille: Task<Void, Never>?

    public init(client: ClientRelais) throws {
        let requete = try client.requeteFlux()
        let tache = client.sessionTerminal.webSocketTask(with: requete)
        let (flux, entree) = AsyncStream.makeStream(of: EvenementFlux.self)
        self.tache = tache
        self.evenements = flux
        self.entree = entree
        entree.onTermination = { @Sendable [weak self] _ in self?.tache.cancel(with: .goingAway, reason: nil) }
    }

    /// Ouvre le socket, lit les trames et veille la liaison (un ping tout de suite, puis à chaque échéance).
    public func ouvrir() {
        tache.resume()
        Task { await lire() }
        relancerVeille()
    }

    /// Premier plan : un ping tout de suite ; sans pong dans le délai, le flux se termine (ModeleRelais le refait).
    public func verifier() async {
        await vivacite.forcerPing()
        relancerVeille()
    }

    public func fermer() {
        veille?.cancel()
        tache.cancel(with: .goingAway, reason: nil)
        entree.finish()
    }

    private func lire() async {
        while true {
            do {
                let trame = try await tache.receive()
                await vivacite.recu()
                if let message = Self.decoder(trame) { entree.yield(.message(message)) }
            } catch {
                Trace.info("flux", "liaison coupée (\(error.localizedDescription))")
                entree.yield(.ferme(error.localizedDescription))
                entree.finish()
                return
            }
        }
    }

    private func relancerVeille() {
        veille?.cancel()
        veille = Task { await veiller() }
    }

    /// Veille : un ping à chaque échéance. Pas de pong dans le délai = liaison morte : le flux se termine avec une
    /// raison, pour que le modèle la refasse. Un pong sans erreur signale que la liaison vit.
    private func veiller() async {
        while !Task.isCancelled && tache.state == .running {
            switch await vivacite.action() {
            case .rien:
                break
            case .ping:
                await vivacite.pingPartie()
                sonder()
            case .morte:
                Trace.info("flux", "liaison morte : aucun pong du relais")
                entree.yield(.ferme("aucun pong du relais"))
                fermer()
                return
            }
            try? await Task.sleep(for: await vivacite.attente())
        }
    }

    private func sonder() {
        tache.sendPing { [vivacite, entree] erreur in
            if let erreur {
                Trace.detail("flux", "ping sans pong (\(erreur.localizedDescription))")
                return
            }
            Task { await vivacite.recu() }
            entree.yield(.ouvert)
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
