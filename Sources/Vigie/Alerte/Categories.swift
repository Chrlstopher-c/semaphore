// Les catégories de notification, donc les boutons qui apparaissent sous une
// alerte sur l'écran verrouillé.
//
// Porté de `NotificationCatalog.swift` du banc EchoLabs, où chaque capacité
// listée ici a été MESURÉE sur l'appareil : actions sur écran verrouillé,
// `authenticationRequired` (Face ID avant exécution), `destructive` (bouton
// rouge), saisie de texte sans ouvrir l'app, regroupement par `threadIdentifier`.
#if canImport(SwiftUI)
import UserNotifications
import VigieNoyau

enum CategoriesAlerte {

    /// Identifiants d'action. `☠` Ils voyagent dans `UNNotificationResponse` et
    /// sont comparés tels quels par `ActionRecue` : les recopier à la main dans
    /// un écran finirait par diverger.
    enum Action {
        static let approuverMandat = "vigie.mandat.approuver"
        static let refuserMandat = "vigie.mandat.refuser"
        static let accorderRallonge = "vigie.rallonge.accorder"
        static let refuserRallonge = "vigie.rallonge.refuser"
        static let ouvrir = "vigie.ouvrir"
    }

    /// Posé une fois au lancement. Une catégorie absente ne produit pas
    /// d'erreur : la notification s'affiche simplement sans ses boutons, ce qui
    /// se voit tard et mal — d'où le compteur exposé par le diagnostic.
    static func poser() {
        UNUserNotificationCenter.current().setNotificationCategories(toutes)
    }

    static var toutes: Set<UNNotificationCategory> {
        [mandat, rallonge, arbitrage, fil, parc, silence, signature]
    }

    /// `☠` Le seul geste réellement engageant de l'application : il dispatche
    /// une équipe qui dépense de l'argent. `authenticationRequired` impose donc
    /// Face ID avant exécution, mesuré fonctionnel sur l'appareil.
    private static var mandat: UNNotificationCategory {
        categorie(
            GenreAlerte.mandat.categorie,
            actions: [
                UNNotificationAction(
                    identifier: Action.approuverMandat,
                    title: "Autoriser",
                    options: [.authenticationRequired]
                ),
                UNNotificationAction(
                    identifier: Action.refuserMandat,
                    title: "Refuser",
                    options: [.destructive, .authenticationRequired]
                ),
            ]
        )
    }

    private static var rallonge: UNNotificationCategory {
        categorie(
            GenreAlerte.rallonge.categorie,
            actions: [
                UNNotificationAction(
                    identifier: Action.accorderRallonge,
                    title: "Accorder",
                    options: [.authenticationRequired]
                ),
                UNNotificationAction(
                    identifier: Action.refuserRallonge,
                    title: "Refuser",
                    options: [.destructive, .authenticationRequired]
                ),
            ]
        )
    }

    /// `☠` AUCUN bouton, et c'est le seul refus délibéré du produit : arbitrer
    /// une inspection, c'est décider si une équipe qui semble boucler doit être
    /// arrêtée. Ça se décide en lisant le motif du verdict, jamais sur deux mots
    /// de bannière. On ouvre l'app, on lit, on tranche.
    private static var arbitrage: UNNotificationCategory {
        categorie(GenreAlerte.arbitrage.categorie, actions: [ouvrirVigie])
    }

    /// Une réponse arrivée dans un fil quitté en cours de génération.
    private static var fil: UNNotificationCategory {
        categorie(GenreAlerte.reponse.categorie, actions: [ouvrirVigie])
    }

    /// Pas de bouton : une fin d'équipe ne se tranche pas, elle se lit.
    private static var parc: UNNotificationCategory {
        categorie(GenreAlerte.parc.categorie, actions: [ouvrirVigie])
    }

    private static var silence: UNNotificationCategory {
        categorie(GenreAlerte.silence.categorie, actions: [ouvrirVigie])
    }

    private static var signature: UNNotificationCategory {
        categorie(GenreAlerte.signature.categorie, actions: [])
    }

    private static var ouvrirVigie: UNNotificationAction {
        UNNotificationAction(identifier: Action.ouvrir, title: "Ouvrir Vigie", options: [.foreground])
    }

    private static func categorie(
        _ identifiant: String,
        actions: [UNNotificationAction]
    ) -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: identifiant,
            actions: actions,
            intentIdentifiers: [],
            options: [.hiddenPreviewsShowTitle]
        )
    }
}
#endif
