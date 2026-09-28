import Foundation

// Les routes de l'API ccremote v2. Un seul endroit : un chemin écrit à la main ailleurs est une faute.

public enum Route {
    public static let connexion = "/api/connexion"
    public static let etat = "/api/etat"
    public static let sessions = "/api/sessions"
    public static let notificationsLues = "/api/notifications/lues"

    public static func attente(version: Int, notifications: Int, attendre: Int = 25) -> String {
        "/api/attente?version=\(version)&notifications=\(notifications)&attendre=\(attendre)"
    }

    public static func evenements(_ session: String, apres: Int? = nil, attendre: Int = 0) -> String {
        guard let apres else { return "/api/sessions/\(session)/evenements" }
        return "/api/sessions/\(session)/evenements?apres=\(apres)&attendre=\(attendre)"
    }

    public static func messages(_ session: String) -> String { "/api/sessions/\(session)/messages" }
    public static func autonomie(_ session: String) -> String { "/api/sessions/\(session)/autonomie" }
    public static func repondre(_ session: String) -> String { "/api/sessions/\(session)/repondre" }
    public static func action(_ session: String, _ action: ActionSession) -> String {
        "/api/sessions/\(session)/\(action.rawValue)"
    }

    public static func reveiller(_ machine: String) -> String { "/api/machines/\(machine)/reveiller" }
    public static func eteindre(_ machine: String) -> String { "/api/machines/\(machine)/eteindre" }
}
