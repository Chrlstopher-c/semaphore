// Ce qui attend une décision de Chris, quel que soit le circuit d'où ça vient.
//
// `☠` Les trois circuits sont SÉPARÉS côté serveur, et ils le restent ici : un
// mandat ouvre une équipe, une rallonge règle un fil, un arbitrage arrête un
// travail en cours. Ce type ne les fond pas — il les met dans une même file et
// leur donne un ordre. Chaque cas garde son objet d'origine intact, et c'est la
// carte qui décide comment il se montre.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

/// Les trois natures de décision. L'ordre de déclaration EST l'ordre d'urgence.
public enum GenreDecision: String, CaseIterable, Identifiable, Sendable {
    /// Une équipe tourne en boucle en ce moment et brûle de l'argent : c'est le
    /// seul cas où l'attente coûte à la seconde.
    case arbitrage
    /// L'orchestrateur est bloqué tant que ce n'est pas tranché.
    case mandat
    /// Rien n'est bloqué : c'est un réglage d'autonomie qui attend.
    case rallonge

    public var id: String { rawValue }

    public var titre: String {
        switch self {
        case .arbitrage: return "Arbitrages"
        case .mandat: return "Mandats"
        case .rallonge: return "Rallonges"
        }
    }

    /// Symboles antérieurs à iOS 15 : l'appareil est plafonné iOS 18 et un
    /// symbole absent se rend en carré vide, sans erreur ni trace.
    public var symbole: String {
        switch self {
        case .arbitrage: return "exclamationmark.octagon.fill"
        case .mandat: return "hand.raised.fill"
        case .rallonge: return "clock.arrow.circlepath"
        }
    }

    var rang: Int {
        switch self {
        case .arbitrage: return 0
        case .mandat: return 1
        case .rallonge: return 2
        }
    }
}

/// Une ligne de la file, avec l'objet serveur qu'elle porte, tel quel.
public enum Decision: Identifiable, Hashable, Sendable {
    case arbitrage(MissionApi)
    case mandat(PropositionApi)
    case rallonge(RallongeApi)

    /// `☠` L'identifiant est PRÉFIXÉ par le genre. Les trois registres du
    /// control plane numérotent chacun de leur côté ; un `p-1` de proposition et
    /// un `p-1` de rallonge s'annuleraient dans un `ForEach`, et la carte
    /// affichée ne serait pas celle qu'on tranche.
    public var id: String {
        switch self {
        case .arbitrage(let mission): return "arbitrage:\(mission.id)"
        case .mandat(let proposition): return "mandat:\(proposition.id)"
        case .rallonge(let demande): return "rallonge:\(demande.id)"
        }
    }

    /// L'identifiant NU, celui que la route attend dans son chemin.
    public var identifiantServeur: String {
        switch self {
        case .arbitrage(let mission): return mission.id
        case .mandat(let proposition): return proposition.id
        case .rallonge(let demande): return demande.id
        }
    }

    public var genre: GenreDecision {
        switch self {
        case .arbitrage: return .arbitrage
        case .mandat: return .mandat
        case .rallonge: return .rallonge
        }
    }

    /// Le fil d'où vient la demande, quand il y en a un. `nil` sur un mandat-cadre
    /// et sur un arbitrage, qui portent sur une équipe, pas sur une conversation.
    public var filDOrigine: String? {
        switch self {
        case .arbitrage: return nil
        case .mandat(let proposition): return proposition.conversationId
        case .rallonge(let demande): return demande.conversationId
        }
    }

    /// Ce que la carte annonce en une ligne, pour les tampons et les toasts.
    public var intitule: String {
        switch self {
        case .arbitrage(let mission): return mission.title
        case .mandat(let proposition): return proposition.projet
        case .rallonge(let demande): return Lisible.objetRallonge(demande)
        }
    }

    /// Depuis quand ça attend. Sert au tri, jamais à l'affichage : les cartes
    /// affichent l'heure de dépôt, qui est ce qu'on lit à 3 h du matin.
    var deposeeA: Date {
        switch self {
        case .arbitrage(let mission):
            // `lastAt` absent alors que l'arbitrage est ouvert : on la traite
            // comme la plus ancienne plutôt que comme la plus récente. Une
            // décision dont on ignore l'âge n'a aucune raison de passer en
            // dernier.
            guard let ms = mission.inspection.lastAt else { return .distantPast }
            return Lisible.instant(ms)
        case .mandat(let proposition): return Lisible.instant(proposition.creeA)
        case .rallonge(let demande): return Lisible.instant(demande.creeA)
        }
    }
}

extension Array where Element == Decision {
    /// Le tri de la file : par urgence de genre, puis la plus ancienne d'abord.
    ///
    /// `☠` Le budget d'un mandat n'entre PAS dans le tri. Un mandat à 40 $ qui
    /// double un mandat à 5 $ posé avant lui rendrait l'ordre imprévisible d'un
    /// relevé à l'autre, et la carte visée sous le pouce changerait de place.
    /// L'urgence est structurelle, jamais monétaire.
    func trieesParUrgence() -> [Decision] {
        sorted { gauche, droite in
            if gauche.genre.rang != droite.genre.rang { return gauche.genre.rang < droite.genre.rang }
            if gauche.deposeeA != droite.deposeeA { return gauche.deposeeA < droite.deposeeA }
            return gauche.id < droite.id
        }
    }
}
#endif
