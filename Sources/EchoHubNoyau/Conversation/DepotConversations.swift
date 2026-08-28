import Foundation

/// L'interface publique du domaine `Conversation` côté réseau.
///
/// Les écrans passent par ici et jamais par `ClientEchoHub` directement : c'est
/// la frontière qui fait qu'un changement de route HTTP ne se propage pas dans
/// six vues. Le domaine connaît les chemins de l'API `chat` d'EchoHub v2 ; les
/// vues ne connaissent que ces méthodes.
///
/// `☠` Décision d'architecture : AUCUNE persistance locale. L'historique vit
/// sur le PC, dans le SQLite d'EchoHub v2, et le téléphone est un client mince.
/// C'est ce qui évite le seul vrai piège d'une app de chat multi-appareils — la
/// synchronisation de deux bases qui divergent — et c'est ce qui fait qu'une
/// conversation commencée au navigateur se reprend au téléphone sans rien
/// faire. Le prix est assumé : hors ligne, il n'y a rien à lire.
public struct DepotConversations: Sendable {
    let client: ClientEchoHub

    public init(client: ClientEchoHub) {
        self.client = client
    }

    public func lister(archivees: Bool = false) async throws -> [ResumeConversation] {
        try await client.lire(
            [ResumeConversation].self, "GET", "chat/conversations?archivees=\(archivees)"
        )
    }

    public func detail(_ identifiant: String) async throws -> ConversationDetaillee {
        try await client.lire(ConversationDetaillee.self, "GET", "chat/conversations/\(identifiant)")
    }

    public func creer(_ demande: CreationConversation) async throws -> ResumeConversation {
        let corps = try CodageJSON.encodeur().encode(demande)
        return try await client.lire(
            ResumeConversation.self, "POST", "chat/conversations", corps: corps
        )
    }

    public func modifier(
        _ identifiant: String, _ patch: MajConversation
    ) async throws -> ResumeConversation {
        let corps = try CodageJSON.encodeur().encode(patch)
        return try await client.lire(
            ResumeConversation.self, "PATCH", "chat/conversations/\(identifiant)", corps: corps
        )
    }

    public func supprimer(_ identifiant: String) async throws {
        try await client.executer("DELETE", "chat/conversations/\(identifiant)")
    }

    /// Demande l'arrêt de la génération en cours. Sans effet s'il n'y en a pas —
    /// et c'est voulu : le bouton « arrêter » ne doit jamais rendre d'erreur
    /// parce que le modèle vient de finir une milliseconde plus tôt.
    public func annuler(_ identifiant: String) async throws {
        try await client.executer("POST", "chat/conversations/\(identifiant)/annuler")
    }

    /// Ouvre le flux d'un nouveau tour. Voir `FluxGeneration` : ce flux ne lance
    /// jamais, il rend un événement `.erreur`.
    public func generer(
        _ identifiant: String, _ demande: DemandeGeneration
    ) -> AsyncStream<EvenementFlux> {
        fluxAvecCorps("chat/conversations/\(identifiant)/generer", demande)
    }

    /// Rejoue un message dans une sous-branche. L'existant est conservé :
    /// l'ancienne réponse reste accessible en variante.
    public func rejouer(
        _ identifiant: String, message: String, modeleId: String? = nil
    ) -> AsyncStream<EvenementFlux> {
        fluxAvecCorps(
            "chat/conversations/\(identifiant)/messages/\(message)/rejouer",
            DemandeRejeu(modeleId: modeleId)
        )
    }

    /// Prompt système et échantillonnage de la conversation. Lus, jamais
    /// devinés : les défauts recopiés dans `ReglagesConversation` ne servent
    /// qu'à afficher un écran avant la première réponse.
    public func reglages(_ identifiant: String) async throws -> ReglagesConversation {
        try await client.lire(
            ReglagesConversation.self, "GET", "chat/conversations/\(identifiant)/reglages"
        )
    }

    /// Patch partiel — voir `MajReglages` et son piège à trois états.
    @discardableResult
    public func definirReglages(
        _ identifiant: String, _ patch: MajReglages
    ) async throws -> ReglagesConversation {
        let corps = try CodageJSON.encodeur().encode(patch)
        return try await client.lire(
            ReglagesConversation.self, "PATCH",
            "chat/conversations/\(identifiant)/reglages", corps: corps
        )
    }

    /// Édite un message utilisateur : le nouveau texte ouvre une branche SŒUR,
    /// puis la génération repart de là. L'historique n'est jamais réécrit — le
    /// message d'origine et la réponse qu'il avait obtenue restent dans l'arbre.
    /// Refusé en 422 sur une réponse du modèle.
    public func editer(
        _ identifiant: String, message: String, contenu: String, modeleId: String? = nil
    ) -> AsyncStream<EvenementFlux> {
        fluxAvecCorps(
            "chat/conversations/\(identifiant)/messages/\(message)/editer",
            DemandeEdition(contenu: contenu, modeleId: modeleId)
        )
    }

    /// Bascule la vue vers la branche qui contient ce message, et rend le chemin
    /// obtenu — c'est ce qui sert les flèches « ‹ 2 / 3 › ».
    public func activerBranche(
        _ identifiant: String, message: String
    ) async throws -> EtatBranche {
        let corps = try CodageJSON.encodeur().encode(ActivationBranche(messageId: message))
        return try await client.lire(
            EtatBranche.self, "POST", "chat/conversations/\(identifiant)/branche", corps: corps
        )
    }

    private func fluxAvecCorps(
        _ chemin: String, _ demande: some Encodable
    ) -> AsyncStream<EvenementFlux> {
        guard let corps = try? CodageJSON.encodeur().encode(demande) else {
            Journal.echec("corps de génération non encodable pour \(chemin)")
            return AsyncStream { suite in
                suite.yield(.erreur(EvenementErreur(
                    code: nil, message: "Message impossible à encoder.", remediation: nil
                )))
                suite.finish()
            }
        }
        return FluxGeneration.ouvrir(client: client, chemin: chemin, corps: corps)
    }
}

/// Corps d'un rejeu — le modèle peut changer d'un essai à l'autre, le reste
/// vient des réglages de la conversation.
struct DemandeRejeu: Encodable {
    var modeleId: String?
}

/// Corps d'une édition : le rejeu, plus le nouveau texte.
struct DemandeEdition: Encodable {
    var contenu: String
    var modeleId: String?
}

/// Corps de `POST .../branche` : l'identifiant de la variante à afficher.
struct ActivationBranche: Encodable {
    var messageId: String
}
