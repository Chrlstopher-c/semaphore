import Foundation

/// Une ligne du fil d'une mission (`vue-feed.ts`).
///
/// `☠` Ce type N'A AUCUN IDENTIFIANT. Voir `FeedEventApi.indexer` : le lui
/// synthétiser est obligatoire avant tout affichage en liste.
public struct FeedEventApi: Decodable, Sendable, Hashable {
    /// Heure murale `HH:MM:SS`, déjà formatée. Bonne à AFFICHER, jamais à
    /// calculer : deux évènements de part et d'autre de minuit donnent un écart
    /// négatif de 24 h.
    public let ts: String
    /// Le même instant en millisecondes epoch. LA seule base de calcul de durée.
    public let at: Int
    public let type: TypeFeedApi
    public let text: String
    public let nature: NatureFeedApi?
    public let tool: String?
    public let auto: Bool?
    public let pending: Bool?
    public let resolved: String?
    public let path: String?
    /// Sortie de l'outil, tronquée à la source. Absente tant que le résultat
    /// n'est pas revenu — un appel sans sortie est un appel encore en vol, pas
    /// un appel qui a répondu du vide.
    public let result: String?
    public let resultError: Bool?
}

/// Une ligne de fil munie d'une clé stable, prête pour une liste SwiftUI.
public struct EvenementFilMission: Sendable, Hashable, Identifiable {
    public let id: String
    public let evenement: FeedEventApi

    public var at: Int { evenement.at }
}

extension FeedEventApi {
    /// Donne à chaque ligne une identité qui SURVIT au sondage suivant.
    ///
    /// `☠` Sans ça, SwiftUI change l'identité des vues à chaque relevé : les
    /// blocs dépliés se referment, le défilement est rejeté, la sélection
    /// s'annule. C'est l'équivalent exact de la RÈGLE ABSOLUE du contrat côté
    /// web, qui interdit de réécrire le DOM dans une boucle périodique.
    ///
    /// La clé est `(at, type, rang)` où `rang` compte les lignes précédentes qui
    /// partagent le MÊME instant et le MÊME type. Compter par couple plutôt que
    /// par instant seul rend la clé insensible à l'insertion d'une ligne d'un
    /// autre type à la même milliseconde — le fil mêle deux sources (transitions
    /// puis activités) triées ensuite sur `at`.
    ///
    /// Ce qui la rend stable : le serveur rend le fil ENTIER à chaque appel, du
    /// plus ancien au plus récent, et une ligne déjà rendue ne change plus. Un
    /// ajout se fait donc en queue, sans décaler les rangs déjà attribués.
    public static func indexer(_ lignes: [FeedEventApi]) -> [EvenementFilMission] {
        var rangs: [String: Int] = [:]
        return lignes.map { ligne in
            let couple = "\(ligne.at)|\(ligne.type.rawValue)"
            let rang = rangs[couple, default: 0]
            rangs[couple] = rang + 1
            return EvenementFilMission(id: "\(couple)|\(rang)", evenement: ligne)
        }
    }
}

public enum DureeFil {
    /// Durée entre deux lignes, en millisecondes. Toujours sur `at`, jamais sur `ts`.
    public static func entre(_ premier: FeedEventApi, _ second: FeedEventApi) -> Int {
        second.at - premier.at
    }

    /// Durée depuis chaque ligne jusqu'à la suivante — ce que l'écran affiche
    /// entre deux blocs. La dernière n'en a pas.
    public static func intervalles(_ lignes: [FeedEventApi]) -> [Int?] {
        lignes.enumerated().map { index, ligne in
            guard index + 1 < lignes.count else { return nil }
            return lignes[index + 1].at - ligne.at
        }
    }
}

/// Un sous-agent d'une équipe.
///
/// La liste vient du TRANSCRIT du PC, jamais du flux temps réel — mesuré non
/// déterministe (0 à 4 lignes livrées sur 5 sous-agents réellement lancés).
public struct SubagentApi: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    /// La description du dispatch quand elle existe, sinon le type, sinon l'id.
    public let name: String
    public let role: String
    public let status: StatutSousAgentApi
    public let action: String
    /// Vide dans la mission ; rempli par `GET /missions/{id}/agents/{agentId}`.
    public let feed: [FeedEventApi]
    /// L'agent EXISTE (le disque le prouve) mais rien de lisible n'a été relevé.
    /// À afficher sans détail — jamais masqué, jamais rempli d'un texte inventé.
    public let feedUnavailable: Bool
}
