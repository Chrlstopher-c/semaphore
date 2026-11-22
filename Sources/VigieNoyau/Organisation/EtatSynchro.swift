import Foundation

// Responsabilité : ce que la synchro d'une machine dit, en français, pour les réglages (« à jour il y a 5 min »,
// « hors ligne · vue il y a 2 h », « ne répond pas », « dernière synchro hier »). Les faits viennent du relais
// (machine, lien ouvert ou non) et de l'organisation gardée. Pur.

public enum EtatSynchro: Equatable, Sendable {
    /// La machine est en ligne et joignable, et sa dernière synchro réussie est à `depuis`.
    case aJour(depuis: Date)
    /// Pas de lecture du relais en cours : on montre la dernière synchro réussie.
    case ancienne(depuis: Date)
    case horsLigne(vue: Date?)
    /// En ligne au relais, mais son accès au poste est injoignable : ses favoris ne sont plus rafraîchis.
    case neRepondPas
    case jamais

    /// `machine` : ce que le relais dit de la machine (nil : inconnue) ; `relaisJoint` : lien ouvert.
    public static func de(machine: Machine?, entree: Organisation.Machine?, relaisJoint: Bool) -> EtatSynchro {
        guard relaisJoint, let machine else { return entree?.derniereSync.map { .ancienne(depuis: $0) } ?? .jamais }
        if !machine.enLigne { return .horsLigne(vue: DateRelative.date(machine.derniereVue)) }
        if machine.acces?.etat == "injoignable" { return .neRepondPas }
        return entree?.derniereSync.map { .aJour(depuis: $0) } ?? .jamais
    }

    public func libelle(maintenant: Date) -> String {
        switch self {
        case .aJour(let depuis): return "à jour " + Self.depuis(depuis, maintenant)
        case .ancienne(let depuis): return "dernière synchro " + Self.depuis(depuis, maintenant)
        case .horsLigne(let vue):
            guard let vue else { return "hors ligne" }
            return "hors ligne · vue " + Self.depuis(vue, maintenant)
        case .neRepondPas: return "ne répond pas"
        case .jamais: return "jamais synchronisée"
        }
    }

    static func depuis(_ date: Date, _ maintenant: Date) -> String {
        let texte = DateRelative.texte(date: date, maintenant: maintenant)
        switch texte {
        case "maintenant": return "à l’instant"
        case "hier": return "hier"
        default: return texte.hasSuffix("min") || texte.hasSuffix("h") ? "il y a \(texte)" : "le \(texte)"
        }
    }
}
