#if canImport(SwiftUI)
import Foundation
import UIKit
import UserNotifications
import VigieNoyau

/// Ce qu'une notification apprend au domaine `Alerte`, réduit à des valeurs
/// transportables.
///
/// `☠` NI `UNNotification` NI `UNNotificationResponse` NE TRAVERSENT UNE
/// FRONTIÈRE D'ISOLATION. Ce sont des classes ObjC non `Sendable` : les passer
/// dans un `Task` ne compile pas en concurrence stricte, et les faire passer de
/// force marcherait jusqu'au premier plantage inexplicable. On extrait donc les
/// chaînes ici, sur l'acteur principal, AVANT de franchir quoi que ce soit.
public struct FaitNotifie: Sendable, Equatable {
    public let identifiant: String
    public let categorie: String
    public let fil: String?
    /// `userInfo` réduit à ses paires de chaînes — le reste ne sert à rien ici.
    public let donnees: [String: String]
    /// Identifiant de l'action choisie, ou `UNNotificationDefaultActionIdentifier`.
    public let action: String
    /// Texte saisi depuis la notification, quand l'action en accepte un.
    public let saisie: String?
}

/// Ce que le domaine `Alerte` branche sur le délégué.
///
/// La coquille ne connaît que ce protocole : elle ne sait pas ce qu'`Alerte`
/// fait d'un fait notifié, et n'a pas à le savoir.
@MainActor
public protocol EcouteurNotifications: AnyObject {
    /// Faut-il montrer la bannière alors que Vigie est déjà à l'écran ?
    func presenter(_ fait: FaitNotifie) -> Bool
    /// Une action a été choisie, éventuellement depuis l'écran verrouillé.
    func recevoir(_ fait: FaitNotifie) async
}

/// Le délégué d'application. Existe pour une seule raison : les rappels de
/// notification arrivent par UIKit et par `UNUserNotificationCenter`, pas par
/// SwiftUI, et ils doivent être installés avant que quoi que ce soit ne soit
/// affiché.
@MainActor
public final class DelegueApplication: NSObject, UIApplicationDelegate {

    /// Branché par le domaine `Alerte`. Nul tant qu'il ne l'est pas : une
    /// notification reçue avant est ignorée, pas perdue — le centre la conserve
    /// et `Alerte` la rattrapera à l'ouverture.
    ///
    /// Statique, et c'est délibéré : `UIApplicationDelegateAdaptor` construit sa
    /// propre instance, hors de portée de tout le reste du programme. Une
    /// propriété d'instance serait posée sur un objet et lue sur un autre.
    public static weak var ecouteur: (any EcouteurNotifications)?

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = RelaisNotifications.partage
        Self.ecouteur = ActionRecue.partage
        // `☠` L'enregistrement des tâches de fond DOIT se faire ici, avant tout
        // retour : iOS refuse tout enregistrement passé le lancement, et l'échec
        // ne se manifeste qu'à l'exécution.
        Reprise.enregistrer()
        Trace.info("coquille", "application lancée")
        return true
    }
}

/// Le relais entre les rappels ObjC non isolés et l'acteur principal.
///
/// Séparé du délégué d'application parce que `UNUserNotificationCenterDelegate`
/// n'est pas annoté `@MainActor` : ses méthodes arrivent `nonisolated`, et c'est
/// ici — et nulle part ailleurs — qu'on assume l'isolation.
final class RelaisNotifications: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let partage = RelaisNotifications()

    /// `☠` L'extraction se fait AVANT toute frontière d'isolation. Une
    /// `UNNotification`, une `UNNotificationResponse` et le bloc d'achèvement
    /// ne sont pas `Sendable` : les capturer dans une fermeture isolée les fait
    /// traverser, ce que la concurrence stricte refuse. Seul `FaitNotifie`, qui
    /// n'est que des chaînes, a le droit de passer.
    ///
    /// `assumeIsolated` et non `Task { @MainActor }` pour la présentation : le
    /// centre appelle déjà sur le fil principal, et un saut de tâche ferait
    /// revenir la décision d'affichage APRÈS que le système ait cessé
    /// d'attendre la réponse.
    nonisolated func userNotificationCenter(
        _ centre: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler achever: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let fait = Self.extraire(notification.request, action: "", saisie: nil)
        let montrer = MainActor.assumeIsolated {
            DelegueApplication.ecouteur?.presenter(fait) ?? true
        }
        achever(montrer ? [.banner, .list, .sound, .badge] : [])
    }

    nonisolated func userNotificationCenter(
        _ centre: UNUserNotificationCenter,
        didReceive reponse: UNNotificationResponse,
        withCompletionHandler achever: @escaping () -> Void
    ) {
        let saisie = (reponse as? UNTextInputNotificationResponse)?.userText
        let fait = Self.extraire(
            reponse.notification.request,
            action: reponse.actionIdentifier,
            saisie: saisie
        )
        let terminer = UncheckedSendable(achever)
        Task { @MainActor in
            await DelegueApplication.ecouteur?.recevoir(fait)
            terminer.valeur()
        }
    }

    /// L'extraction : tout ce qui traversera est déjà une chaîne à la sortie.
    /// `nonisolated` à dessein — elle ne touche que la requête reçue en
    /// paramètre, sur le fil où le système l'a livrée.
    nonisolated private static func extraire(
        _ requete: UNNotificationRequest,
        action: String,
        saisie: String?
    ) -> FaitNotifie {
        let brut = requete.content.userInfo
        // `as? String` sur un `Any` venu du pont ObjC : c'est la seule forme
        // possible, `userInfo` n'a pas de type plus précis côté système.
        var donnees: [String: String] = [:]
        for (cle, valeur) in brut {
            guard let nom = cle as? String, let texte = valeur as? String else { continue }
            donnees[nom] = texte
        }
        return FaitNotifie(
            identifiant: requete.identifier,
            categorie: requete.content.categoryIdentifier,
            fil: requete.content.threadIdentifier.isEmpty ? nil : requete.content.threadIdentifier,
            donnees: donnees,
            action: action,
            saisie: saisie
        )
    }
}

/// Enveloppe le bloc d'achèvement du système, qui n'est pas `Sendable` mais que
/// UserNotifications garantit appelable une fois, depuis n'importe quel fil.
private struct UncheckedSendable<Valeur>: @unchecked Sendable {
    let valeur: Valeur

    init(_ valeur: Valeur) { self.valeur = valeur }
}
#endif
