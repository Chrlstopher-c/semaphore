import Foundation

// Responsabilité : les constantes et calculs de la liaison temps réel avec le relais (flux WebSocket, repli sur le
// long-poll, reprise). Pur : l'app câble ces valeurs, elle ne les réécrit pas.

public enum LiaisonRelais {
    /// Ping client : le relais coupe une liaison muette au-delà de son délai d'inactivité.
    public static let pingSecondes: UInt64 = 25
    /// Échecs consécutifs du WebSocket avant de repasser par le long-poll `/api/attente`.
    public static let echecsAvantRepli = 3
    public static let attenteMinimale = 2
    public static let attenteMaximale = 30

    /// Attente avant la reprise suivante : doublée, bornée.
    public static func attenteSuivante(_ secondes: Int) -> Int {
        min(max(secondes, attenteMinimale) * 2, attenteMaximale)
    }

    /// Adresse du flux : même hôte, schéma ws ou wss selon http ou https ; `nil` pour un schéma inconnu.
    public static func adresseFlux(_ adresse: URL) -> URL? {
        guard var composants = URLComponents(url: adresse, resolvingAgainstBaseURL: false) else { return nil }
        switch composants.scheme {
        case "https": composants.scheme = "wss"
        case "http": composants.scheme = "ws"
        default: return nil
        }
        return composants.url
    }

    /// L'état complet, sessions archivées comprises (le relais les écarte sinon).
    public static func etatAvecArchivees() -> String { Route.etat + "?archivees=1" }

    /// Le long-poll, sessions archivées comprises : la liste ne perd pas ses archives à chaque changement.
    public static func attenteAvecArchivees(version: Int, notifications: Int) -> String {
        Route.attente(version: version, notifications: notifications) + "&archivees=1"
    }
}
