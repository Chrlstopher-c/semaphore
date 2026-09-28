// Les gestes envoyés au serveur : chemin + corps JSON. La `famille` sert à la file « le plus récent gagne » :
// pendant un glissé sur la roue, seule la dernière couleur en attente part, sans écraser un allumage en attente.
import Foundation

public enum Commande: Equatable, Sendable {
    case allumer(Bool)
    case couleur(Nuance)
    case intensite(Int)
    /// `nil` arrête l'animation : le serveur repose la couleur fixe.
    case effet(Int?)
    case vitesse(Int)
    case ajouterFavori(String)
    case retirerFavori(String)

    public var chemin: String {
        switch self {
        case .allumer: return "/api/power"
        case .couleur: return "/api/color"
        case .intensite: return "/api/brightness"
        case .effet: return "/api/effect"
        case .vitesse: return "/api/speed"
        case .ajouterFavori: return "/api/favorites"
        case .retirerFavori: return "/api/favorites/remove"
        }
    }

    public var famille: String { chemin }

    public var corps: Data {
        let objet: [String: Any]
        switch self {
        case .allumer(let oui): objet = ["on": oui]
        case .couleur(let nuance): objet = ["color": nuance.hexa]
        case .intensite(let valeur): objet = ["value": valeur]
        case .effet(let code): objet = ["code": code.map { $0 as Any } ?? NSNull()]
        case .vitesse(let valeur): objet = ["value": valeur]
        case .ajouterFavori(let hexa), .retirerFavori(let hexa): objet = ["color": hexa]
        }
        return (try? JSONSerialization.data(withJSONObject: objet, options: [.sortedKeys])) ?? Data()
    }
}

/// File d'envoi : une commande par famille au plus, dans l'ordre de première arrivée.
public struct FileCommandes: Sendable {
    private var attente: [Commande] = []

    public init() {}

    public var estVide: Bool { attente.isEmpty }

    public mutating func deposer(_ commande: Commande) {
        if let rang = attente.firstIndex(where: { $0.famille == commande.famille }) {
            attente[rang] = commande
        } else {
            attente.append(commande)
        }
    }

    public mutating func prendre() -> Commande? {
        attente.isEmpty ? nil : attente.removeFirst()
    }
}
