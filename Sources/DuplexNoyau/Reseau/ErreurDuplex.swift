import Foundation

/// Ce qui peut rater entre l'iPhone et le PC, dit en français et actionnable.
/// Le message est destiné à être AFFICHÉ : il dit où la chaîne a cassé — le
/// réseau, le jumelage, le PC — parce que ce ne sont pas les mêmes réparations.
public enum ErreurDuplex: Error, Sendable, Equatable {
    /// Aucun PC publié sur `_duplex._tcp`, ou la découverte refusée par iOS.
    case decouverteImpossible(String)
    case injoignable(String)
    /// Opération ANNULÉE localement (on a quitté l'écran, on a coupé l'écoute).
    /// Pas une panne : rien à réparer, rien à montrer.
    case annule
    /// Le PC a refusé le jumelage — code faux trois fois, ou jeton mort.
    case refuse(String)
    /// Le port UDP n'a pas pu s'ouvrir : sans lui, aucun son n'arrive.
    case portIndisponible(String)
    case reponseIllisible(String)

    public var libelle: String {
        switch self {
        case .decouverteImpossible(let detail):
            return "Aucun PC trouvé sur le réseau — \(detail)"
        case .injoignable(let detail):
            return "PC injoignable — \(detail)"
        case .annule:
            return "Écoute interrompue."
        case .refuse(let raison):
            return raison.isEmpty ? "Jumelage refusé par le PC." : raison
        case .portIndisponible(let detail):
            return "Impossible d'ouvrir le port d'écoute — \(detail)"
        case .reponseIllisible(let detail):
            return "Réponse illisible : \(detail)"
        }
    }

    public var remede: String? {
        switch self {
        case .decouverteImpossible:
            return "Vérifie que Duplex tourne sur le PC et que les deux sont sur le même Wi-Fi."
        case .injoignable:
            return "Vérifie le Wi-Fi du téléphone et que le PC est allumé."
        case .refuse:
            return "Relance le jumelage et recopie le code affiché sur le PC."
        case .portIndisponible:
            return "Relance l'écoute ; si ça persiste, redémarre l'app."
        case .annule, .reponseIllisible:
            return nil
        }
    }

    /// Une annulation locale — jamais une panne à montrer.
    public var estAnnulation: Bool {
        if case .annule = self { return true }
        return false
    }

    /// Reconnaît une annulation venue du réseau ou de la concurrence, AVANT
    /// traduction, pour lever `.annule` plutôt que `.injoignable`. Sans ce
    /// filtre, couper l'écoute afficherait « PC injoignable » à chaque fois.
    public static func vientDUneAnnulation(_ erreur: Error) -> Bool {
        if erreur is CancellationError { return true }
        if let url = erreur as? URLError, url.code == .cancelled { return true }
        return false
    }
}
