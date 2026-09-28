// Ce que rend le serveur Lueur du Pi (`GET /api/state`, et `state` dans chaque réponse d'action).
import Foundation

public struct EtatLumiere: Codable, Equatable, Sendable {
    public var allume: Bool
    public var couleur: String
    public var intensite: Int
    public var effet: Int?
    /// La dernière animation lancée : ce que rallume l'interrupteur « Animation ». Absente des serveurs anciens.
    public var dernierEffet: Int?
    public var vitesse: Int
    public var favoris: [String]
    /// Le Pi tient-il la liaison Bluetooth avec le ruban ? Faux = serveur joint, LED injoignables.
    public var relie: Bool

    enum CodingKeys: String, CodingKey {
        case allume = "power", couleur = "color", intensite = "brightness"
        case effet = "effect", dernierEffet = "last_effect"
        case vitesse = "speed", favoris = "favorites", relie = "connected"
    }

    public init(allume: Bool, couleur: String, intensite: Int, effet: Int?, dernierEffet: Int? = nil,
                vitesse: Int, favoris: [String], relie: Bool) {
        self.allume = allume
        self.couleur = couleur
        self.intensite = intensite
        self.effet = effet
        self.dernierEffet = dernierEffet
        self.vitesse = vitesse
        self.favoris = favoris
        self.relie = relie
    }
}

/// Réponse d'une action : `sent` faux = la trame n'a pas atteint le ruban.
public struct ReponseAction: Decodable, Sendable {
    public let envoye: Bool
    public let etat: EtatLumiere

    enum CodingKeys: String, CodingKey { case envoye = "sent", etat = "state" }
}

/// Une animation intégrée au contrôleur.
public struct Effet: Codable, Hashable, Identifiable, Sendable {
    public let code: Int
    public let nom: String
    public var id: Int { code }

    enum CodingKeys: String, CodingKey { case code, nom = "name" }

    public init(code: Int, nom: String) {
        self.code = code
        self.nom = nom
    }
}
