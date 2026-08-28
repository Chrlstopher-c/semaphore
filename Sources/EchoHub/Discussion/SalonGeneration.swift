// L'envoi d'un message et la consommation du flux. Séparé de `Salon.swift` par
// domaine — l'état d'un côté, le tour de génération de l'autre.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

extension Salon {
    /// Envoie un message et consomme le flux jusqu'au bout.
    ///
    /// Ne rend rien et ne lance pas : tout ce qui peut rater arrive dans le flux
    /// sous forme d'événement `.erreur`, et se peint sous le fil. L'écran n'a
    /// donc qu'un seul chemin, pas deux.
    /// Met le texte en file plutôt que de le refuser, quand un tour est déjà
    /// ouvert. Rend `true` si le message est parti tout de suite.
    @discardableResult
    public func envoyerOuFileDAttente(_ texte: String) -> Bool {
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !propre.isEmpty else { return false }
        guard !enGeneration else {
            poser(enAttente: propre)
            return false
        }
        envoyer(propre)
        return true
    }

    /// Retire le message en attente. Il n'a jamais atteint le PC : rien à
    /// annuler côté serveur.
    public func annulerAttente() { poser(enAttente: nil) }

    public func envoyer(_ texte: String) {
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let conversation, !propre.isEmpty, !enGeneration else { return }
        poser(erreur: nil)
        poser(message: messageLocal(propre, dans: conversation.id))
        // Seules les pièces réellement posées partent : une montée en cours ou
        // ratée ne doit pas bloquer un texte qui, lui, est prêt.
        let demande = DemandeGeneration(
            contenu: propre, modeleId: statutPret?.modele,
            fichierIds: piecesJointes.compactMap(\.identifiantServeur)
        )
        viderPiecesJointes()
        lancer(conversations.generer(conversation.id, demande))
    }

    /// Consomme un flux de génération, quel que soit le geste qui l'a ouvert :
    /// envoi, rejeu, édition. Le contrat d'événements est le même pour les trois
    /// — c'est ce qui permet aux branches de ne rien réécrire.
    func lancer(_ flux: AsyncStream<EvenementFlux>) {
        poser(tache: Task { [weak self] in
            await self?.consommer(flux)
            self?.poser(tache: nil)
            await self?.conclureTour()
        })
    }

    /// Relit le fil au serveur à la fin d'un tour réussi.
    ///
    /// Un tour crée des variantes (rejeu, édition) et déplace la feuille active :
    /// tout ça vit dans l'arbre du PC, pas ici. Une relecture coûte un GET là où
    /// la génération vient d'en coûter mille fois plus. En cas d'échec, on ne
    /// relit rien : le message d'erreur doit rester lisible.
    private func conclureTour() async {
        guard erreurGeneration == nil else { return }
        await recharger()
        await mesurerContexte()
        // Le message tapé pendant le tour part maintenant, et pas avant : deux
        // générations concurrentes sur une conversation écriraient deux réponses
        // pour un seul tour, et le serveur les refuse (409).
        if let attendu = enAttente {
            poser(enAttente: nil)
            envoyer(attendu)
        }
    }

    /// `☠` Une SEULE requête par tour, jamais par fragment : elle envoie tous
    /// les messages, et vingt mesures par seconde à travers le tunnel coûteraient
    /// plus que la génération elle-même. Un échec est silencieux à l'écran — une
    /// ligne d'information manquante ne doit pas peindre une erreur — mais
    /// journalisé.
    private func mesurerContexte() async {
        guard !messages.isEmpty else { return }
        do {
            poser(occupation: try await modeles.occupationContexte(
                promptSysteme: reglagesConversation?.promptSysteme ?? "", messages: messages
            ))
        } catch {
            Journal.echec("occupation du contexte non mesurée : \(error)")
            poser(occupation: nil)
        }
    }

    /// Demande l'arrêt de la génération en cours.
    ///
    /// Deux gestes, et les deux comptent : annuler la tâche locale — ce qui
    /// ferme le flux, donc la requête — ET prévenir le PC, qui sinon continue de
    /// générer dans le vide pour un lecteur qui n'écoute plus.
    public func arreter() {
        // L'ordre compte : annuler d'abord ferme le flux, donc arrête l'écriture
        // dans `enCours` — sinon un fragment en vol arriverait APRÈS le dépôt et
        // se perdrait dans un `enCours` déjà remis à nil.
        poser(tache: nil)
        deposerEnCours(interrompu: true)
        guard let conversation else { return }
        prevenirLePC(conversation.id)
    }

    /// `☠` Le `try?` d'avant avalait l'échec. Chris appuyait sur Arrêter,
    /// l'interface s'arrêtait proprement — et le PC continuait de générer, GPU
    /// occupé, jusqu'au bout de la réponse. Un arrêt qui n'a pas arrêté est
    /// exactement l'état qu'il faut connaître : c'est de la VRAM, et une réponse
    /// fantôme qui provoquera un refus au prochain envoi.
    private func prevenirLePC(_ identifiant: String) {
        let depot = conversations
        Task { [weak self] in
            do {
                try await depot.annuler(identifiant)
            } catch {
                Journal.echec("annulation côté PC échouée : \(error)")
                // Le fil a pu changer entre-temps : ne rien écrire sur une
                // conversation qui n'est plus celle qu'on a tenté d'arrêter.
                guard self?.conversation?.id == identifiant else { return }
                self?.poser(erreur: "L'arrêt n'a pas atteint le PC — il génère "
                    + "peut-être encore. \(Salon.libelle(error))")
            }
        }
    }

    /// L'app passe en arrière-plan pendant une génération.
    ///
    /// `☠` On ferme le flux local SANS prévenir le PC. Le backend poursuit la
    /// génération sur `GeneratorExit` et persiste la réponse COMPLÈTE
    /// (`backend/chat/generation.py`) : appeler `annuler` détruirait du texte
    /// déjà payé en VRAM. Avant ce crochet, iOS suspendait l'app, le flux
    /// mourait, et la réponse tronquée se voyait estampiller « Interrompu » —
    /// un texte définitif et faux, que rien dans l'app ne permettait de
    /// corriger.
    public func suspendre() {
        guard enGeneration else { return }
        poser(tache: nil)
        deposerEnCours(interrompu: true, affirmeParLeServeur: false)
    }

    /// Retour au premier plan : le PC est la source de vérité, on la relit.
    public func reprendre() async {
        guard demarre else { return }
        await rafraichirStatut()
        await recharger()
    }

    /// Le message de Chris, posé AVANT toute réponse du serveur.
    ///
    /// `☠` Identifiant local provisoire : le vrai arrive dans l'événement
    /// `debut` (`messageUtilisateurId`) et le remplace. Attendre le serveur pour
    /// afficher ce que Chris vient de taper ferait un trou d'une seconde entre
    /// le geste et son effet — c'est le défaut qui fait retaper.
    private func messageLocal(_ texte: String, dans conversation: String) -> MessageChat {
        MessageChat(
            id: Salon.prefixeLocal + UUID().uuidString, conversationId: conversation,
            role: .user, contenu: texte
        )
    }

    private func consommer(_ flux: AsyncStream<EvenementFlux>) async {
        for await evenement in flux {
            switch evenement {
            case .debut(let debut):
                accueillir(debut)
            case .fragment(let texte):
                ajouter(fragment: texte)
            case .compaction(let info):
                // Arrive après `debut`, avant les fragments : le message à venir
                // est déjà connu. La balise se peint au-dessus de la réponse qui
                // s'écrit, et le rechargement de fin de tour la retrouvera sur
                // `MessageChat.compaction`.
                poser(compaction: info)
            case .fin(let fin):
                deposerEnCours(interrompu: fin.interrompu, mesures: fin)
                noterChangementDeListe()
            case .erreur(let erreur):
                deposerEnCours(interrompu: true)
                poser(erreur: [erreur.message, erreur.remediation]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
            case .termine:
                deposerEnCours(interrompu: false)
            }
        }
        // Le flux s'est fermé sans `fin` — coupure réseau, app suspendue. Ce qui
        // était écrit est conservé, et marqué DOUTEUX : l'app ne sait pas si le
        // serveur a interrompu ou si c'est elle qui a cessé d'écouter.
        deposerEnCours(interrompu: true, affirmeParLeServeur: false)
    }

    /// Aligne l'état local sur ce que le serveur vient de décider : le vrai
    /// identifiant du message de Chris, et celui de la réponse à venir.
    private func accueillir(_ debut: EvenementDebut) {
        // Un tour neuf ne porte pas la balise du précédent. La sienne, s'il en a
        // une, arrive juste après ce `debut`.
        poser(compaction: nil)
        if let reel = debut.messageUtilisateurId,
           let local = messages.last(where: { Salon.estLocal($0.id) })?.id {
            remplacerIdentifiant(de: local, par: reel)
        }
        poser(enCours: MessageEnCours(
            id: debut.messageId, parentId: debut.parentId,
            modeleId: debut.modeleId, texte: ""
        ))
    }

    /// Fait passer la réponse en cours dans les messages établis.
    ///
    /// Sans effet s'il n'y a rien en cours : `deposerEnCours` est appelé sur
    /// plusieurs chemins qui peuvent se croiser (fin normale, erreur, fermeture
    /// du flux, arrêt manuel), et un tour ne doit jamais produire deux messages.
    private func deposerEnCours(
        interrompu: Bool, affirmeParLeServeur: Bool = true, mesures: EvenementFin? = nil
    ) {
        guard let courant = enCours, let conversation else { return }
        poser(enCours: nil)
        marquer(courant.id, douteux: interrompu && !affirmeParLeServeur)
        poser(message: MessageChat(
            id: courant.id, conversationId: conversation.id, role: .assistant,
            contenu: courant.texte, tokensGeneres: mesures?.tokensGeneres,
            tokensParSeconde: mesures?.tokensParSeconde, modeleId: courant.modeleId,
            interrompu: interrompu, parentId: courant.parentId
        ))
    }
}
#endif
