import Foundation

// Responsabilité : ce que les canaux demandent au client (HoteAppareil) — transport des messages, identité
// du nœud, états du lien, réponses de l'API clients, révocation et fermeture de canal.

extension ClientAiguilleur: Chiffrement.HoteAppareil {
    func envoyerAiguilleur(_ message: ProtocoleAiguilleur.VersAiguilleur) async {
        guard let tache = transport else { return }
        do {
            try await tache.envoyer(message)
        } catch {
            // Un envoi refusé coupe le lien : la boucle le relève et reprend.
            Trace.erreur("aiguilleur", "envoi refusé, lien coupé", error)
            await tache.fermer()
        }
    }

    func identitePairee(_ membre: String) async -> Chiffrement.IdentitePublique? {
        guard membre == etat.noeud, let texte = etat.identiteNoeud else { return nil }
        return try? Chiffrement.Identites.importer(texte)
    }

    func appairageAccepte(membre: String, nom: String, identite: Chiffrement.IdentitePublique) async {
        etat.identiteNoeud = Chiffrement.Identites.exporter(identite)
        etat.nomNoeud = nom
        await surEtat(etat)
    }

    func liaisonOuverte(canal: String) async {
        delaiReprise = delais.repriseInitiale
        await surLien(.ouvert)
    }

    func liaisonRefusee(canal: String, raison: String) async {
        // « révoqué » : le nœud ne reconnaît plus cet appareil (révocation passée) — même sens qu'une révocation.
        if raison == MotifsRevocation.noeud { return await revoquerLien() }
        await refuserLien(raison)
    }

    func recevoir(canal: String, message: ProtocoleAiguilleur.DuLien) async {
        switch message {
        case let .apiReponse(ref, statut, corps, codage, type, morceaux):
            guard let complet = corpsComplet(ref, corps, morceaux) else {
                return await requetes.echouer(ref, ErreurAiguilleur("transfert de la réponse interrompu"))
            }
            await requetes.resoudre(ref, ReponseRequete(statut: statut, corps: complet, codage: codage, type: type))
        case let .morceau(ref, rang, corps):
            _ = reassemblage.recevoir(ref: ref, rang: rang, corps: corps)
        case .revocation:
            await revoquerLien()
        case .diffusionOuverte:
            diffusion?.yield(.ouverte)
        case let .diffusion(ref, corps, morceaux):
            guard let complet = corpsComplet(ref, corps, morceaux) else { return }
            recevoirDiffusion(complet)
        case let .reponse(ref, ok, raison):
            await requetes.resoudre(ref, ReponseRequete(statut: ok ? 200 : 409, corps: raison ?? ""))
        case let .terminalSortie(terminal, base64):
            livrerTerminal(terminal, base64)
        case let .terminalFin(terminal, code):
            finirTerminal(terminal, code)
        case .api, .terminalPoste, .terminalEntree, .terminalTaille, .terminalFermer,
             .diffusionOuvrir, .diffusionFermer:
            return
        }
    }

    /// Le corps d'un message, réuni depuis ses morceaux s'il en a ; nil si le transfert est cassé.
    func corpsComplet(_ ref: String, _ corps: String, _ morceaux: Int?) -> String? {
        guard let morceaux else { return corps }
        return reassemblage.assembler(ref: ref, nombre: morceaux)
    }

    func canalFerme(canal: String) async {
        Trace.info("aiguilleur", "canal \(canal) terminé (courant : \(canal == canalCourant))")
        canaux.removeValue(forKey: canal)
        reassemblage.vider()
        await requetes.echouerTout(ErreurAiguilleur("le lien vers le nœud est fermé"))
        finirDiffusion("le lien vers le nœud est fermé")
        finirTerminaux("le lien vers le nœud est fermé")
        guard canal == canalCourant else { return }
        canalCourant = nil
        if !bloque { await surLien(.rechercheNoeud) }
        planifierReprise()
    }
}
