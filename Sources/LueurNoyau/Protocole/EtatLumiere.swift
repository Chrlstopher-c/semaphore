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
    /// Le scénario que joue le Pi (routine ou essai), absent sinon.
    public var lecture: Lecture?

    public struct Lecture: Codable, Equatable, Sendable {
        public let id: String
    }

    enum CodingKeys: String, CodingKey {
        case allume = "power", couleur = "color", intensite = "brightness"
        case effet = "effect", dernierEffet = "last_effect"
        case vitesse = "speed", favoris = "favorites", relie = "connected", lecture = "playing"
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

extension EtatLumiere {
    /// L'état tel qu'il sera une fois le geste joué : appliqué tout de suite à l'écran, sans attendre le Pi (sinon les
    /// commandes revenaient en arrière le temps du fondu, puis repartaient — Chris, 28/11/2026).
    public mutating func appliquer(_ commande: Commande) {
        switch commande {
        case .allumer(let oui): allume = oui
        case .couleur(let nuance): allume = true; couleur = nuance.hexa; effet = nil
        case .intensite(let valeur): allume = true; intensite = valeur
        case .effet(let code): allume = true; effet = code; if let code { dernierEffet = code }
        case .vitesse(let valeur): vitesse = valeur
        case .ajouterFavori(let hexa): if !favoris.contains(hexa) { favoris.append(hexa) }
        case .retirerFavori(let hexa): favoris.removeAll { $0 == hexa }
        }
    }
}
