// Les liens `semaphore://` : ce que fait l'app quand on la rouvre depuis l'extérieur (notification push ntfy touchée).
//   semaphore://session/<id>  → ouvre la session ; semaphore://  → ouvre simplement l'app.
#if canImport(SwiftUI)
import Foundation

public enum LienProfond {
    public static let schema = "semaphore"

    /// Session de Quart demandée et pas encore ouverte : le pupitre s'en sert pour revenir à Quart.
    @MainActor public static var sessionEnAttente: String? { Aiguillage.partage.sessionDemandee }

    /// Rend `true` si le lien est le nôtre (qu'il désigne une session ou non).
    @MainActor
    @discardableResult
    public static func ouvrir(_ url: URL) -> Bool {
        guard url.scheme == schema else { return false }
        guard url.host == "session", let id = url.pathComponents.dropFirst().first, !id.isEmpty else { return true }
        Aiguillage.partage.sessionDemandee = id
        return true
    }
}
#endif
