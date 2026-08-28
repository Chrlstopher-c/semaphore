import Foundation

/// Une ligne de la liste des conversations : tout sauf les messages.
public struct ResumeConversation: Sendable, Codable, Identifiable, Hashable {
    public let id: String
    public var titre: String
    public var modeleId: String?
    public let creeLe: Date
    public var majLe: Date
    public var archivee: Bool
    public var nbMessages: Int

    public init(
        id: String, titre: String, modeleId: String? = nil,
        creeLe: Date = .now, majLe: Date = .now,
        archivee: Bool = false, nbMessages: Int = 0
    ) {
        self.id = id
        self.titre = titre
        self.modeleId = modeleId
        self.creeLe = creeLe
        self.majLe = majLe
        self.archivee = archivee
        self.nbMessages = nbMessages
    }
}

/// Ce que rend `GET /api/chat/conversations/{id}` : la conversation, ses
/// réglages, et le CHEMIN ACTIF de l'arbre — pas l'arbre entier.
public struct ConversationDetaillee: Sendable, Codable {
    public let conversation: ResumeConversation
    public let reglages: ReglagesConversation
    public let messages: [MessageChat]
    /// La feuille du chemin actif. Décodée pour rester fidèle au contrat, mais
    /// l'app n'en dérive rien : `messages` EST déjà le chemin actif, et la
    /// bascule de branche passe par `POST /branche`, qui rend le chemin complet.
    /// Le web s'en sert pour son arbre ; le téléphone n'affiche pas d'arbre.
    public let feuilleActive: String?
    /// Pour chaque message du chemin, les identifiants qui partagent son parent,
    /// lui compris. C'est ce qui donne le « 2 / 3 » sans rien recalculer.
    public let variantes: [String: [String]]

    public init(
        conversation: ResumeConversation,
        reglages: ReglagesConversation,
        messages: [MessageChat],
        feuilleActive: String? = nil,
        variantes: [String: [String]] = [:]
    ) {
        self.conversation = conversation
        self.reglages = reglages
        self.messages = messages
        self.feuilleActive = feuilleActive
        self.variantes = variantes
    }
}

/// Corps de `POST /api/chat/conversations`.
public struct CreationConversation: Sendable, Encodable {
    public var titre: String
    public var modeleId: String?
    /// Les réglages posés à la création. C'est par ce champ — et seulement par
    /// lui — que l'app applique sa sélection d'outils par défaut : le serveur
    /// n'a pas de réglage global, `outils_actifs` est une colonne par
    /// conversation. Voir `OutilsParDefaut`.
    ///
    /// `☠` Absent quand le défaut vaut « hériter du registre » : `nil` sur une
    /// propriété `Encodable` synthétisée OMET la clé, et le serveur applique
    /// alors ses propres défauts. Envoyer un objet vide dirait la même chose,
    /// mais par accident.
    public var reglages: ReglagesCreation?

    public init(
        titre: String = "Nouvelle conversation", modeleId: String? = nil,
        outilsParDefaut: SelectionOutils = SelectionOutils()
    ) {
        self.titre = titre
        self.modeleId = modeleId
        self.reglages = outilsParDefaut.outilsActifs.map(ReglagesCreation.init(outilsActifs:))
    }
}

/// Le sous-ensemble des réglages qu'on pose à la création.
///
/// `☠` Volontairement RÉDUIT au seul champ que l'app décide. Le contrat pydantic
/// de `ReglagesConversation` est en `extra="forbid"` : tout champ inventé ferait
/// échouer la création entière. Et les champs omis prennent les défauts du
/// domaine, ce qui est exactement ce qu'on veut d'une conversation neuve — poser
/// un prompt système vide et des paramètres d'échantillonnage recopiés ici
/// ferait diverger deux sources du même défaut.
public struct ReglagesCreation: Sendable, Encodable, Equatable {
    /// `[]` = aucun outil, une liste = ceux-là. Non optionnel : le troisième
    /// état — « hériter du registre » — fait disparaître `reglages` entier, il
    /// n'a pas de représentation ici.
    public var outilsActifs: [String]

    public init(outilsActifs: [String]) {
        self.outilsActifs = outilsActifs
    }
}

/// Corps de `PATCH /api/chat/conversations/{id}` — patch partiel : seuls les
/// champs fournis sont écrits côté serveur.
public struct MajConversation: Sendable, Encodable {
    public var titre: String?
    public var archivee: Bool?

    public init(titre: String? = nil, archivee: Bool? = nil) {
        self.titre = titre
        self.archivee = archivee
    }
}

/// Ce que rendent `GET` et `POST /api/chat/conversations/{id}/branche` : la vue
/// courante de l'arbre, chemin actif et frères de chacun de ses messages.
///
/// Le serveur est le SEUL à connaître l'arbre. On lui envoie l'identifiant de
/// la variante choisie, il rend le chemin complet à afficher — l'app n'a rien à
/// reconstruire, et ne peut donc pas diverger de lui.
public struct EtatBranche: Sendable, Codable {
    public let conversationId: String
    public let feuilleActive: String?
    public let messages: [MessageChat]
    public let variantes: [String: [String]]

    public init(
        conversationId: String,
        feuilleActive: String? = nil,
        messages: [MessageChat] = [],
        variantes: [String: [String]] = [:]
    ) {
        self.conversationId = conversationId
        self.feuilleActive = feuilleActive
        self.messages = messages
        self.variantes = variantes
    }
}
