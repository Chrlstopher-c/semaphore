// Les branches : rejouer une réponse, éditer une question, se déplacer entre
// les variantes. Un domaine à part de l'envoi — c'est le même flux, mais le
// geste, lui, réécrit le chemin affiché avant de le rouvrir.
//
// `☠` Rien n'est recalculé ici. Le PC porte l'arbre entier ; l'app lui envoie
// un identifiant et affiche le chemin qu'il rend. C'est ce qui garantit que le
// « ‹ 2 / 3 › » du téléphone et celui du navigateur désignent la même chose.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

extension Salon {
    /// Relance une réponse du modèle dans une branche sœur. L'ancienne n'est pas
    /// détruite : elle reste accessible en variante.
    ///
    /// Avant ce geste, une réponse ratée obligeait à retaper la question — ce qui
    /// empile un tour de plus au lieu d'ouvrir une variante, et pollue
    /// durablement le contexte du modèle.
    public func rejouer(_ message: MessageChat) {
        guard let conversation, message.role == .assistant, !enGeneration else { return }
        poser(erreur: nil)
        tronquerAvant(message.id)
        lancer(conversations.rejouer(
            conversation.id, message: message.id, modeleId: statutPret?.modele
        ))
    }

    /// Réécrit une question déjà envoyée. Le message d'origine et la réponse
    /// qu'il avait obtenue restent lisibles dans l'arbre du PC : c'est la seule
    /// façon d'éditer sans détruire ce qui s'est réellement passé.
    public func editer(_ message: MessageChat, contenu: String) {
        let propre = contenu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let conversation, message.role == .user, !propre.isEmpty, !enGeneration,
              !Self.estLocal(message.id) else { return }
        poser(erreur: nil)
        tronquerAvant(message.id)
        // Le nouveau texte s'affiche AVANT la réponse du serveur, comme à
        // l'envoi : son identifiant réel arrive dans l'événement `debut`.
        poser(message: MessageChat(
            id: Salon.prefixeLocal + UUID().uuidString, conversationId: conversation.id,
            role: .user, contenu: propre
        ))
        lancer(conversations.editer(
            conversation.id, message: message.id, contenu: propre, modeleId: statutPret?.modele
        ))
    }

    /// Affiche une autre variante du même tour. Le serveur rend le chemin
    /// complet ; on le pose tel quel.
    public func afficherVariante(_ identifiant: String) async {
        guard let conversation, !enGeneration else { return }
        do {
            appliquer(try await conversations.activerBranche(conversation.id, message: identifiant))
        } catch {
            Journal.echec("bascule de branche impossible : \(error)")
            poser(erreur: "Variante inaccessible — \(Self.libelle(error))")
        }
    }

    /// La position d'un message parmi ses frères. Le calcul lui-même vit dans
    /// le noyau (`NavigationVariante`), où il est éprouvé sans appareil.
    public func positionVariante(de message: MessageChat) -> (rang: Int, total: Int)? {
        NavigationVariante.position(de: message.id, dans: variantes)
    }

    public func variante(de message: MessageChat, decalage: Int) -> String? {
        NavigationVariante.voisin(de: message.id, decalage: decalage, dans: variantes)
    }

    /// Coupe le chemin affiché juste avant ce message : ce qui suivait
    /// appartient à l'ancienne branche, et le serveur va en ouvrir une neuve.
    /// Rien n'est perdu — l'arbre du PC garde tout, et un rechargement le montre.
    private func tronquerAvant(_ identifiant: String) {
        guard let rang = messages.firstIndex(where: { $0.id == identifiant }) else { return }
        remplacerMessages(Array(messages.prefix(upTo: rang)))
    }
}
#endif
