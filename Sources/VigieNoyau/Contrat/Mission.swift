import Foundation

/// Une équipe du parc, telle que `GET /missions` et `GET /missions/{id}` la rendent.
///
/// Trois champs sont ABSENTS de ce type alors qu'ils existent dans le JSON, et
/// c'est délibéré :
///  - `landing` vaut toujours `null` côté serveur (« aucune source réelle ») ;
///  - `freshlyDispatched` et `ultracode` sont câblés en dur à `false`
///    (`vue-missions.ts` : « transitoires d'interface, sans source côté
///    serveur »). Les décoder les ferait passer pour des mesures.
public struct MissionApi: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let project: String
    /// Chaîne vide quand la mission n'a pas de worktree — jamais `null`.
    public let worktree: String
    public let branch: String
    /// Identifiant du compte Claude, pas son libellé : c'est la clé de jointure
    /// avec `AccountApi.id`.
    public let account: String
    /// Machine où l'équipe tourne. `nil` ⇒ mission antérieure au multi-machines.
    public let machine: String?
    /// `nil` = JAMAIS MESURÉ, ce qui n'est pas « propre ». Une équipe qui rend la
    /// main avec du travail non commité était présentée comme ayant livré.
    public let git: ConstatGitApi?
    /// Décodé TEL QUEL. Voir `EtatMissionApi` : le recalculer croiserait deux
    /// machines à états et rejouerait la panne #30.
    public let state: EtatMissionApi
    /// Pourcentage de contexte, mesuré. `0` = pas encore de relevé, jamais une
    /// extrapolation : on décide d'un atterrissage sur ce chiffre.
    public let ctx: Int
    public let ctxDetail: [PosteContexteApi]
    public let ctxTokens: TokensContexteApi
    public let cost: Double
    /// Effectif compté sur le transcript : « lead seul » ou « lead + N sous-agents ».
    public let team: String
    public let model: String
    public let epoch: Int
    /// Déjà formaté par le serveur : « 1 / 3 ».
    public let retries: String
    public let sessionId: String?
    public let mandate: MandatMissionApi
    public let inspection: InspectionApi
    /// Un seul de ces quatre libellés est renseigné à la fois — celui qui
    /// correspond à `state`. Ils sont déjà en français et déjà relatifs.
    public let blockedSince: String?
    public let pausedAgo: String?
    public let idleAgo: String?
    public let doneAgo: String?
    public let subagents: [SubagentApi]
    /// Vide sur la LISTE, rempli sur le DÉTAIL.
    public let feed: [FeedEventApi]
    /// Bloc en cours de frappe du lead. Toujours `nil` sur la liste : le relevé
    /// traverse le lien vers la machine et n'est fait que pour la mission
    /// réellement regardée.
    public let partial: PartielApi?
}

/// État du dépôt de l'équipe au dernier relevé.
public struct ConstatGitApi: Decodable, Sendable, Hashable {
    public let uncommitted: Int
    public let branch: String?
    public let lastCommit: String?
    /// Epoch ms du relevé.
    public let at: Int
}

/// Un poste de la ventilation du contexte.
public struct PosteContexteApi: Decodable, Sendable, Hashable {
    public let nom: String
    public let tokens: Int
    /// Poste ANNONCÉ mais PAS chargé : il ne compte pas dans le total. Les
    /// additionner ferait dépasser le total réel de plus du double.
    public let differe: Bool
}

/// Tokens bruts, pour lire autre chose qu'un pourcentage arrondi.
public struct TokensContexteApi: Decodable, Sendable, Hashable {
    public let utilises: Int?
    public let max: Int?
}

public struct MandatMissionApi: Decodable, Sendable, Hashable {
    /// Chaînes vides quand le mandat n'a rien fixé — jamais `null`.
    public let but: String
    public let critere: String
}
