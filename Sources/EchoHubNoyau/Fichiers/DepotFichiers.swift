import Foundation

/// Un fichier de conversation — pièce jointe de Chris ou artefact du modèle.
/// Une référence, jamais un contenu : les octets vivent sur le disque du PC.
public struct FichierConversation: Sendable, Decodable, Identifiable, Hashable {
    public let id: String
    public let conversationId: String
    public let messageId: String?
    public let origine: String
    public let nomAffiche: String
    public let typeMime: String
    public let tailleOctets: Int
    public let creeLe: Date
}

/// L'interface publique du domaine `Fichiers` côté réseau.
///
/// `☠` Le dépôt est IMMÉDIAT, à la sélection — jamais au moment d'envoyer. C'est
/// la règle du web, et elle est bonne : aucun octet ne traverse la route de
/// génération, qui ne transporte que des identifiants. Un envoi ne peut donc
/// jamais échouer pour une photo trop lourde alors que le texte, lui, était bon.
public struct DepotFichiers: Sendable {
    /// Le plafond du serveur, recopié ici pour refuser AVANT de téléverser
    /// 25 Mio en 4G pour rien (`backend/fichiers/politique.py`).
    public static let tailleMaxOctets = 25 * 1024 * 1024

    private let client: ClientEchoHub

    public init(client: ClientEchoHub) {
        self.client = client
    }

    public func deposer(
        conversation: String, nom: String, typeMime: String, octets: Data
    ) async throws -> FichierConversation {
        guard octets.count <= Self.tailleMaxOctets else {
            throw ErreurRelais.serveur(
                statut: 413,
                message: "Fichier trop volumineux (\(octets.count / (1024 * 1024)) Mo).",
                remede: "Le PC accepte 25 Mo par fichier."
            )
        }
        var corps = CorpsMultipart()
        corps.champ("origine", "utilisateur")
        corps.fichier("fichier", nomFichier: nom, typeMime: typeMime, octets: octets)
        return try await client.lire(
            FichierConversation.self, "POST", "conversations/\(conversation)/fichiers",
            corps: corps.terminer(), typeContenu: corps.typeContenu
        )
    }
}
