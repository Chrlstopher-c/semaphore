import Foundation

/// Les paramètres d'échantillonnage d'une conversation.
///
/// Les valeurs par défaut sont celles du serveur (`backend/chat/modeles.py`),
/// recopiées ici pour que l'app puisse afficher un réglage avant d'avoir reçu
/// quoi que ce soit — jamais pour les lui imposer : dès que la conversation est
/// lue, ce sont les valeurs du serveur qui font foi.
///
/// `maxTokens` à `nil` signifie « aucun plafond posé ici » : le moteur va
/// jusqu'à sa propre fenêtre de contexte. Ce n'est pas une absence de réglage,
/// c'est le réglage.
public struct ParametresEchantillonnage: Sendable, Codable, Equatable {
    public var temperature: Double
    public var topP: Double
    public var topK: Int
    public var penaliteRepetition: Double
    public var maxTokens: Int?
    public var sequencesArret: [String]
    public var graine: Int?

    public init(
        temperature: Double = 0.8,
        topP: Double = 0.95,
        topK: Int = 40,
        penaliteRepetition: Double = 1.1,
        maxTokens: Int? = nil,
        sequencesArret: [String] = [],
        graine: Int? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.penaliteRepetition = penaliteRepetition
        self.maxTokens = maxTokens
        self.sequencesArret = sequencesArret
        self.graine = graine
    }
}

/// Prompt système et paramètres attachés à une conversation.
public struct ReglagesConversation: Sendable, Codable, Equatable {
    public var promptSysteme: String
    public var parametres: ParametresEchantillonnage
    /// Compte des MESSAGES, jamais des tokens. `nil` = historique complet.
    public var historiqueMaxMessages: Int?
    /// Les outils mis à disposition du modèle. `nil` = tous ceux du registre,
    /// `[]` = aucun, une liste = ceux-là.
    ///
    /// `☠` Lu ici pour que le fil sache ce qui est coupé SANS une requête de
    /// plus : le serveur le rend déjà avec les réglages, à l'ouverture de la
    /// conversation. La sélection s'ÉCRIT, elle, par `PATCH .../outils` et
    /// `SelectionOutils` — deux chemins, parce que le serveur en a deux.
    public var outilsActifs: [String]?

    public init(
        promptSysteme: String = "",
        parametres: ParametresEchantillonnage = ParametresEchantillonnage(),
        historiqueMaxMessages: Int? = nil,
        outilsActifs: [String]? = nil
    ) {
        self.promptSysteme = promptSysteme
        self.parametres = parametres
        self.historiqueMaxMessages = historiqueMaxMessages
        self.outilsActifs = outilsActifs
    }

    /// La sélection telle que le reste de l'app la manipule.
    public var selectionOutils: SelectionOutils {
        SelectionOutils(outilsActifs: outilsActifs)
    }
}

/// Corps de `POST /api/chat/conversations/{id}/generer`.
///
/// `fichierIds` reste vide dans cette version : le dépôt de pièces jointes
/// (`backend/fichiers/`) n'est pas branché côté iPhone. Le champ est présent
/// parce qu'il fait partie du contrat, pas parce qu'il est utilisé.
public struct DemandeGeneration: Sendable, Encodable {
    public var contenu: String
    public var modeleId: String?
    public var fichierIds: [String]

    public init(contenu: String, modeleId: String? = nil, fichierIds: [String] = []) {
        self.contenu = contenu
        self.modeleId = modeleId
        self.fichierIds = fichierIds
    }
}
