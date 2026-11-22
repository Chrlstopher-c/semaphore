import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Responsabilité : le transport du client vers l'aiguilleur — une interface (envoyer, recevoir, fermer) et son
// implémentation WebSocket (LienAiguilleur). Le client ne connaît que l'interface ; les tests la remplacent.

/// Le lien sortant vers l'aiguilleur, vu par le client. Les messages arrivent dans l'ordre de l'aiguilleur.
protocol TransportAiguilleur: Sendable {
    func envoyer(_ message: ProtocoleAiguilleur.VersAiguilleur) async throws
    func recevoir() async throws -> ProtocoleAiguilleur.DeAiguilleur
    func fermer() async
}

/// Fabrique d'un transport à partir de l'adresse de l'aiguilleur et du jeton de membre.
typealias FabriqueTransport = @Sendable (URL, String) throws -> any TransportAiguilleur

/// Transport réel : un WebSocket `URLSession` (LienAiguilleur). La tâche n'est touchée que par l'acteur client.
final class TransportWebSocket: TransportAiguilleur, @unchecked Sendable {
    private let tache: URLSessionWebSocketTask

    private init(tache: URLSessionWebSocketTask) {
        self.tache = tache
    }

    static func ouvrir(adresse: URL, jeton: String) throws -> any TransportAiguilleur {
        TransportWebSocket(tache: try LienAiguilleur.ouvrir(adresse: adresse, jeton: jeton))
    }

    func envoyer(_ message: ProtocoleAiguilleur.VersAiguilleur) async throws {
        try await LienAiguilleur.envoyer(message, sur: tache)
    }

    func recevoir() async throws -> ProtocoleAiguilleur.DeAiguilleur {
        try await LienAiguilleur.recevoir(sur: tache)
    }

    func fermer() async {
        tache.cancel(with: .goingAway, reason: nil)
    }
}
