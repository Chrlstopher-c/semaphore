import Foundation

// Responsabilité : le flux en direct du nœud par le canal de l'appareil — miroir côté iPhone de DiffusionAppareil
// (Quart, relais/federation/appareil-diffusion.ts). L'appli s'abonne ; le nœud acquitte (`diffusion_ouverte`), puis
// chaque événement du flux arrive en MessageClient, les deltas de texte déjà regroupés. Une fin de canal ou de
// lien termine le flux : l'appli relit alors l'état et se réabonne.

/// Ce que le flux livre à l'appli : l'acquittement, un événement du nœud, la fin (avec sa raison).
public enum EvenementDiffusion: Sendable, Equatable {
    case ouverte
    case message(MessageClient)
    case ferme(String)
}

extension ClientAiguilleur {
    /// Le flux en direct du nœud : `diffusion_ouvrir` part dès que le canal est prêt. Un second appel remplace le
    /// premier ; l'arrêt de la lecture ferme l'abonnement côté nœud.
    public func ouvrirDiffusion() -> AsyncStream<EvenementDiffusion> {
        let (flux, continuation) = AsyncStream.makeStream(of: EvenementDiffusion.self)
        finirDiffusion("remplacé par un nouveau flux")
        let identifiant = UUID()
        diffusion = continuation
        diffusionCourante = identifiant
        continuation.onTermination = { [weak self] _ in
            Task { await self?.abandonnerDiffusion(identifiant) }
        }
        Task { await self.demanderDiffusion() }
        return flux
    }

    /// Le flux part sur chaque canal ouvert (un par nœud) ; un canal qui s'ouvre plus tard le reçoit à son ouverture.
    func demanderDiffusion() async {
        guard (try? await canalOuvert()) != nil else {
            return finirDiffusion("lien vers le nœud non ouvert")
        }
        for canal in await canauxOuverts() { _ = await canal.envoyer(.diffusionOuvrir) }
    }

    /// Un canal vient de s'ouvrir pendant qu'un flux est suivi : il s'y abonne aussitôt.
    func abonnerCanalAuFlux(_ canal: Chiffrement.CanalAppareil) async {
        guard diffusion != nil else { return }
        _ = await canal.envoyer(.diffusionOuvrir)
    }

    /// Le désabonnement venu de l'appli : aucun nœud ne pousse plus rien. Seul le flux courant compte : la fin d'un
    /// flux déjà remplacé ne doit ni fermer le nouveau ni prévenir les nœuds.
    func abandonnerDiffusion(_ identifiant: UUID) async {
        guard diffusionCourante == identifiant, diffusion != nil else { return }
        diffusion = nil
        diffusionCourante = nil
        for canal in await canauxOuverts() { _ = await canal.envoyer(.diffusionFermer) }
    }

    /// Une diffusion du nœud `noeud` (corps entier, déjà réuni) : décodée comme un événement de l'appli, gardée si ce
    /// nœud tient la session ; une trame illisible est écartée sans couper le flux.
    func recevoirDiffusion(_ corps: String, noeud: String?) {
        guard let message = DecodeurDiffusion.lire(corps) else { return }
        guard tenueParNoeud(message, noeud) else { return }
        diffusion?.yield(.message(message))
    }

    /// Un événement d'une session est gardé seulement par le nœud qui la tient : un autre nœud n'en envoie que des
    /// copies fédérées. Une session inconnue passe (la liste du parc la rangera au prochain rafraîchissement).
    func tenueParNoeud(_ message: MessageClient, _ noeud: String?) -> Bool {
        guard let noeud else { return true }
        let session: String?
        switch message {
        case let .evenement(e): session = e.sessionId
        case let .flux(sessionId, _, _, _, _): session = sessionId
        case let .session(s): session = s.id
        case let .filModifie(sessionId): session = sessionId
        case .supprimee, .machine, .notification, .inconnu: session = nil
        }
        guard let session, let tenant = sessionsNoeud[session] else { return true }
        return tenant == noeud
    }

    func finirDiffusion(_ raison: String) {
        guard let flux = diffusion else { return }
        diffusion = nil
        diffusionCourante = nil
        flux.yield(.ferme(raison))
        flux.finish()
    }

    /// Le canal de la cible, prêt, sans attendre (terminal : il reste sur le nœud visé par le lien).
    func canalPret() async -> Chiffrement.CanalAppareil? {
        guard let id = canalCourant, let canal = canaux[id], await canal.estOuvert else { return nil }
        return canal
    }

    /// Les canaux ouverts maintenant, sans attendre : un désabonnement ne doit pas bloquer 20 s.
    func canauxOuverts() async -> [Chiffrement.CanalAppareil] {
        var ouverts: [Chiffrement.CanalAppareil] = []
        for canal in canaux.values {
            if await canal.estOuvert { ouverts.append(canal) }
        }
        return ouverts
    }
}

/// Le décodage d'une diffusion du nœud, à part pour être testé sans réseau.
enum DecodeurDiffusion {
    static func lire(_ corps: String) -> MessageClient? {
        guard let donnees = corps.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MessageClient.self, from: donnees)
    }
}
