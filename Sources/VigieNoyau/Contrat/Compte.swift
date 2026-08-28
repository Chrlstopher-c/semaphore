import Foundation

/// Un compte Claude Code du registre, avec ses deux jauges de quota (H-63/H-70).
///
/// `☠` RAISONNER EN POURCENTAGE, JAMAIS EN DOLLARS (mesuré) : sur abonnement,
/// les champs en dollars de l'API d'usage sont nuls. Une jauge bâtie dessus
/// afficherait 0 en permanence et laisserait saturer le quota sans prévenir.
public struct AccountApi: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let label: String
    /// Chaîne vide quand le registre ne connaît pas l'adresse.
    public let email: String
    /// Statut de la fenêtre 5 h : c'est elle qui décide de la capacité à lancer
    /// une équipe maintenant.
    public let status: StatutQuotaApi
    /// `☠` DISTINCT du statut : `rejected` ne coupe pas la session, elle continue
    /// en dépassement PAYANT. La mission tourne encore, et elle coûte de l'argent
    /// réel — afficher « rejeté » comme un arrêt serait doublement faux.
    public let isUsingOverage: Bool
    /// Vide tant qu'aucune sonde n'a répondu. Un champ vide est honnête ;
    /// l'interface affichait « Max » en dur sur des comptes réellement « Pro ».
    public let plan: String
    public let fiveHour: FenetreApi
    public let sevenDay: FenetreApi

    enum CodingKeys: String, CodingKey {
        case id, label, email, status, isUsingOverage, plan
        // Les seules clés en serpent du contrat — mappées ici plutôt que de
        // laisser deux conventions de nommage se répandre dans le noyau.
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

/// Une fenêtre de quota, déjà mise en forme par le serveur.
public struct FenetreApi: Decodable, Sendable, Hashable {
    /// Consommation 0-100. La seule grandeur fiable sur abonnement.
    public let util: Int
    /// Délai relatif prêt à afficher : « 3 h 30 », « 12 min », « expirée », « — ».
    public let resetLabel: String
    /// Heure exacte du reset — « 10:30 PM », ou « lundi 28 juil. · 08:00 AM »
    /// pour la fenêtre hebdomadaire. `nil` si aucun reset connu ou déjà passé.
    /// `☠` Complète le délai relatif, ne le remplace pas : « dans 3 h 30 » dit
    /// s'il faut attendre, « 10:30 PM » dit s'il faut aller dormir.
    public let resetAt: String?
}
