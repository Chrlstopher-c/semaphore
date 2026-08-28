import Foundation

/// Qui parle. Miroir exact de `RoleMessage` côté EchoHub v2
/// (`backend/chat/modeles.py`) : les trois mêmes valeurs, écrites pareil, parce
/// que ce sont celles qui voyagent sur le fil.
public enum RoleMessage: String, Sendable, Codable, Hashable {
    case system
    case user
    case assistant
}

/// Un message persisté côté PC, tel que l'API le rend.
///
/// `☠` Ce type n'est pas « le message affiché » : il porte le texte BRUT du
/// modèle, balises `<think>` et `<tool_call>` comprises. La séparation entre ce
/// qui se lit et ce qui se replie appartient à `Raisonnement/`, jamais à une
/// vue ni à ce DTO.
public struct MessageChat: Sendable, Codable, Identifiable, Hashable {
    public let id: String
    public let conversationId: String
    public let role: RoleMessage
    public var contenu: String
    public var tokensGeneres: Int?
    public var tokensParSeconde: Double?
    public let creeLe: Date
    public var modeleId: String?
    public var interrompu: Bool
    /// `nil` désigne une racine de conversation. Deux messages de même parent
    /// sont deux variantes du même tour — un rejeu, une édition.
    public var parentId: String?

    public init(
        id: String,
        conversationId: String,
        role: RoleMessage,
        contenu: String,
        tokensGeneres: Int? = nil,
        tokensParSeconde: Double? = nil,
        creeLe: Date = .now,
        modeleId: String? = nil,
        interrompu: Bool = false,
        parentId: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.contenu = contenu
        self.tokensGeneres = tokensGeneres
        self.tokensParSeconde = tokensParSeconde
        self.creeLe = creeLe
        self.modeleId = modeleId
        self.interrompu = interrompu
        self.parentId = parentId
    }
}
