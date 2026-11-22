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

    func demanderDiffusion() async {
        guard let canal = try? await canalOuvert() else {
            return finirDiffusion("lien vers le nœud non ouvert")
        }
        guard await canal.envoyer(.diffusionOuvrir) else {
            finirDiffusion("lien vers le nœud fermé")
            return
        }
    }

    /// Le désabonnement venu de l'appli : le nœud ne pousse plus rien sur ce canal. Seul le flux courant compte : la
    /// fin d'un flux déjà remplacé ne doit ni fermer le nouveau ni prévenir le nœud.
    func abandonnerDiffusion(_ identifiant: UUID) async {
        guard diffusionCourante == identifiant, diffusion != nil else { return }
        diffusion = nil
        diffusionCourante = nil
        guard let canal = await canalPret() else { return }
        _ = await canal.envoyer(.diffusionFermer)
    }

    /// Une diffusion du nœud (corps entier, déjà réuni) : décodée comme un événement de l'appli ; une trame illisible
    /// est écartée sans couper le flux.
    func recevoirDiffusion(_ corps: String) {
        guard let message = DecodeurDiffusion.lire(corps) else { return }
        diffusion?.yield(.message(message))
    }

    func finirDiffusion(_ raison: String) {
        guard let flux = diffusion else { return }
        diffusion = nil
        diffusionCourante = nil
        flux.yield(.ferme(raison))
        flux.finish()
    }

    /// Le canal prêt, sans attendre : une saisie ou un désabonnement ne doit pas bloquer 20 s.
    func canalPret() async -> Chiffrement.CanalAppareil? {
        guard let id = canalCourant, let canal = canaux[id], await canal.estOuvert else { return nil }
        return canal
    }
}

/// Le décodage d'une diffusion du nœud, à part pour être testé sans réseau.
enum DecodeurDiffusion {
    static func lire(_ corps: String) -> MessageClient? {
        guard let donnees = corps.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MessageClient.self, from: donnees)
    }
}
