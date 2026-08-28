import Foundation

/// La balise d'une compaction de contexte, telle qu'elle voyage sur le fil.
///
/// `☠` Contrat STABLE d'EchoHub v2 (`backend/chat/modeles.py`, classe
/// `InfoCompaction`), consommé À L'IDENTIQUE par le web et par le mobile : les
/// noms de champs ne changent pas sans versionner. La compaction ne touche
/// JAMAIS l'historique en base — elle décrit ce que le MOTEUR relit à la place
/// des tours anciens. La balise se rend dans le fil JUSTE AVANT le message
/// assistant `messageId`.
///
/// `snake_case` du serveur → `camelCase` ici via `CodageJSON.decodeur()`
/// (`.convertFromSnakeCase`) : `coupe_message_id`, `nb_messages_resumes`,
/// `tokens_avant`… se décodent sans `CodingKeys`, comme le reste du domaine.
///
/// `Codable` et non seulement `Decodable` : `MessageChat` la porte en propriété
/// et reste `Codable`. Aucun message n'est encodé en entier vers le serveur
/// (l'occupation passe par un DTO réduit), mais la conformité doit se
/// synthétiser.
public struct InfoCompaction: Sendable, Codable, Equatable, Hashable, Identifiable {
    public let id: String
    public let conversationId: String
    /// Message assistant dont la génération a déclenché cette compaction : la
    /// balise se pose immédiatement au-dessus de lui dans le fil.
    public let messageId: String
    /// Dernier message d'historique replié dans le résumé. Tout ce qui suit est
    /// parti mot pour mot au moteur ; tout ce qui précède est remplacé par
    /// `resume`.
    public let coupeMessageId: String
    /// Cumulatif d'une compaction à l'autre : combien de messages du fil ce
    /// résumé remplace côté moteur.
    public let nbMessagesResumes: Int
    public let tokensAvant: Int
    public let tokensApres: Int
    /// La fenêtre du modèle servie.
    public let contexteTotal: Int
    public let resume: String
    public let creeLe: Date

    public init(
        id: String,
        conversationId: String,
        messageId: String,
        coupeMessageId: String,
        nbMessagesResumes: Int,
        tokensAvant: Int,
        tokensApres: Int,
        contexteTotal: Int,
        resume: String,
        creeLe: Date
    ) {
        self.id = id
        self.conversationId = conversationId
        self.messageId = messageId
        self.coupeMessageId = coupeMessageId
        self.nbMessagesResumes = nbMessagesResumes
        self.tokensAvant = tokensAvant
        self.tokensApres = tokensApres
        self.contexteTotal = contexteTotal
        self.resume = resume
        self.creeLe = creeLe
    }
}
