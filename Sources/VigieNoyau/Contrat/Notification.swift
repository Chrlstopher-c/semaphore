import Foundation

/// Un fait du parc destiné à être lu.
///
/// `☠` Deux destinataires, JAMAIS fondus : Chris dans l'interface (`read`) et
/// l'orchestrateur dans son fil (`delivered`). Marquer l'un ne dit rien de
/// l'autre — Chris peut lire une notification que l'orchestrateur n'a jamais
/// reçue, et l'inverse est le cas normal la nuit. Un seul booléen effacerait
/// exactement ce qu'on regarde pour savoir si l'orchestrateur est au courant.
public struct NotificationApi: Decodable, Sendable, Hashable, Identifiable {
    /// `☠` Un UUID v4 : NON ORDONNÉ. Aucun filigrane scalaire ne peut se poser
    /// dessus — voir `FiligraneNotifications`.
    public let id: String
    public let type: TypeNotificationApi
    public let title: String
    public let body: String
    public let missionId: String?
    /// Fil vers lequel rediriger au clic. `nil` ⇒ carte non cliquable, ce qui
    /// vaut mieux qu'un clic qui mène au mauvais fil.
    public let conversationId: String?
    /// Epoch ms. Seule grandeur ordonnée du type : c'est elle qui porte le
    /// filigrane de rattrapage.
    public let createdAt: Int
    public let read: Bool
    /// Le fait est entré dans le contexte de l'orchestrateur.
    public let delivered: Bool
    /// Dernière raison d'échec de remise, à afficher telle quelle si présente.
    public let deliveryError: String?
}

/// Réponse de `GET /notifications`.
public struct ListeNotificationsApi: Decodable, Sendable {
    /// `☠` PLAFONNÉE À 50 côté serveur, et SANS curseur `since`. Deux jours sans
    /// ouvrir Vigie et les plus anciennes ont quitté la fenêtre sans que rien ne
    /// le signale. Ce n'est pas un coût de bande passante, c'est un problème de
    /// justesse — `FiligraneNotifications.rattrapageIncomplet` le dénonce.
    public let notifications: [NotificationApi]
    /// `☠` Le badge se lit ICI, jamais sur `notifications.count` : la liste est
    /// plafonnée et mentirait au-delà.
    public let unread: Int
}

extension ListeNotificationsApi {
    /// Plafond appliqué par le dépôt (`registre/notifications.ts`, `LISTE_DEFAUT`).
    /// Sert à détecter qu'une rafale a pu être tronquée.
    public static let plafondServeur = 50
}
