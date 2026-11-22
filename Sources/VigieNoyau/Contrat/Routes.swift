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

    public static let flux = "/api/flux"
    public static let appairer = "/api/appareils/appairer"
    public static let environnements = "/api/environnements"

    /// Le tout début d'un fil (titre de repli d'une session sans nom). Un relais ancien ignore `limite`.
    public static func premiersEvenements(_ session: String, limite: Int) -> String {
        "/api/sessions/\(session)/evenements?apres=0&limite=\(limite)"
    }

    public static func evenementsAvant(_ session: String, avant: Int, limite: Int) -> String {
        "/api/sessions/\(session)/evenements?avant=\(avant)&limite=\(limite)"
    }

    public static func contexte(_ session: String) -> String { "/api/sessions/\(session)/contexte" }
    public static func taches(_ session: String) -> String { "/api/sessions/\(session)/taches" }
    public static func arreterTache(_ session: String, _ tache: String) -> String {
        "/api/sessions/\(session)/taches/\(tache)/arreter"
    }

    public static func modele(_ session: String) -> String { "/api/sessions/\(session)/modele" }
    public static func effort(_ session: String) -> String { "/api/sessions/\(session)/effort" }
    public static func mode(_ session: String) -> String { "/api/sessions/\(session)/mode" }
    /// Renommer une session (et non un fichier : `renommer(_:)` désigne déjà le renommage de fichier d'une machine).
    public static func renommerSession(_ session: String) -> String { "/api/sessions/\(session)/renommer" }
    public static func ultracode(_ session: String) -> String { "/api/sessions/\(session)/ultracode" }
    public static func projets(_ machine: String) -> String { "/api/machines/\(machine)/projets" }

    /// La parité d'une session : tâches de fond, transcript lisible ou non.
    public static func parite(_ session: String) -> String { "/api/sessions/\(session)/parite" }
    public static func tacheParite(_ session: String, _ tache: String) -> String {
        "/api/sessions/\(session)/parite/taches/\(tache)"
    }
    public static func fichierSession(_ session: String, _ fichier: String) -> String {
        "/api/sessions/\(session)/fichiers/\(fichier)"
    }
}
