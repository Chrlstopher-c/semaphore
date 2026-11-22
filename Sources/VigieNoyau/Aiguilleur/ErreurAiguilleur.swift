import Foundation

// Responsabilité : l'erreur lisible du client de l'aiguilleur (appairage, lien, requête). Son texte va à l'appli.

/// Erreur du client de l'aiguilleur : le message est destiné à l'utilisateur, sans détail technique.
public struct ErreurAiguilleur: Error, Equatable, Sendable, CustomStringConvertible, LocalizedError {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
    public var errorDescription: String? { message }
}
