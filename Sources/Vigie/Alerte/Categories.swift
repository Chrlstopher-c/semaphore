// Les catégories de notification, donc les boutons sous une alerte, écran verrouillé compris.
// Mesuré sur l'appareil (banc EchoLabs) : la saisie de texte marche sans ouvrir l'app — on répond à Claude d'ici.
#if canImport(SwiftUI)
import UserNotifications
import VigieNoyau

enum CategoriesAlerte {
    enum Action {
        static let repondre = "vigie.session.repondre"
        static let ouvrir = "vigie.session.ouvrir"
    }

    static func poser() {
        UNUserNotificationCenter.current().setNotificationCategories([session, simple(.silence), simple(.signature)])
    }

    private static var session: UNNotificationCategory {
        UNNotificationCategory(
            identifier: GenreAlerte.question.categorie,
            actions: [
                UNTextInputNotificationAction(identifier: Action.repondre, title: "Répondre", options: [],
                                              textInputButtonTitle: "Envoyer", textInputPlaceholder: "Ta réponse à la session"),
                UNNotificationAction(identifier: Action.ouvrir, title: "Ouvrir", options: [.foreground]),
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    private static func simple(_ genre: GenreAlerte) -> UNNotificationCategory {
        UNNotificationCategory(identifier: genre.categorie, actions: [], intentIdentifiers: [], options: [])
    }
}
#endif
