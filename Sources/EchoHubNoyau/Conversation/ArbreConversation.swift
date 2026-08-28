import Foundation

/// TOUS les messages d'une conversation, branches abandonnées comprises.
///
/// `☠` C'est la preuve VÉRIFIABLE qu'un rejeu ou une édition n'efface rien. Le
/// fil ne montre que le chemin actif ; ce que ce chemin ne montre plus est
/// toujours là, avec son `parentId`. Sans cet écran, « l'ancienne réponse reste
/// accessible en variante » était une affirmation de la documentation, pas
/// quelque chose que Chris pouvait constater depuis le téléphone.
public struct ArbreConversation: Sendable, Decodable {
    public let conversationId: String
    public let feuilleActive: String?
    public let messages: [MessageChat]

    /// Les messages rangés par parent : c'est la forme dont une vue a besoin
    /// pour descendre l'arbre sans le reconstruire à chaque rangée.
    public var enfantsParParent: [String: [MessageChat]] {
        Dictionary(grouping: messages.filter { $0.parentId != nil }, by: { $0.parentId ?? "" })
    }

    /// Les racines, dans l'ordre d'écriture. Il y en a normalement une ; il peut
    /// y en avoir plusieurs si le premier message a été édité.
    public var racines: [MessageChat] {
        messages.filter { $0.parentId == nil }
    }

    /// Un tour a-t-il plusieurs variantes ? C'est la seule chose qui distingue
    /// un arbre d'une liste, et donc la seule qui mérite d'être signalée.
    public var comporteDesVariantes: Bool {
        let parents = messages.compactMap(\.parentId)
        return Set(parents).count != parents.count || racines.count > 1
    }
}

/// Ce que le serveur répond quand on vide l'historique.
public struct MessagesSupprimes: Sendable, Decodable {
    public let supprimes: Int
}

extension DepotConversations {

    /// L'arbre complet. Coûteux sur une longue conversation : à charger sur un
    /// geste explicite, jamais à l'ouverture du fil.
    public func arbre(_ identifiant: String) async throws -> ArbreConversation {
        try await client.lire(
            ArbreConversation.self, "GET", "chat/conversations/\(identifiant)/arbre"
        )
    }

    /// Vide l'historique en CONSERVANT la conversation, son titre et ses
    /// réglages.
    ///
    /// `☠` Irréversible et total : l'arbre entier part, variantes comprises.
    /// C'est un geste de la même famille que supprimer une conversation, et il
    /// doit passer par la même confirmation qui dit sa portée réelle — sans
    /// quoi « vider » se lira comme « replier ».
    @discardableResult
    public func viderMessages(_ identifiant: String) async throws -> MessagesSupprimes {
        try await client.lire(
            MessagesSupprimes.self, "DELETE", "chat/conversations/\(identifiant)/messages"
        )
    }
}
