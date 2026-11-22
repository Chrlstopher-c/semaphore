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
        guard let texte = etat.noeuds[membre]?.identite else { return nil }
        return try? Chiffrement.Identites.importer(texte)
    }

    func appairageAccepte(membre: String, nom: String, identite: Chiffrement.IdentitePublique) async {
        etat.noeuds[membre] = NoeudConnu(identite: Chiffrement.Identites.exporter(identite), nom: nom)
        refuses.remove(membre)
        await surEtat(etat)
        await publierNoeuds()
    }

    func liaisonOuverte(canal: String) async {
        // Seul le canal de la cible porte l'état du lien ; un autre nœud s'abonne seulement au flux en cours.
        if canal == canalCourant {
            delaiReprise = delais.repriseInitiale
            await surLien(.ouvert)
            await publierNoeuds()
            demanderNoeuds()
        }
        if let ouvert = canaux[canal] { await abonnerCanalAuFlux(ouvert) }
    }

    func liaisonRefusee(canal: String, raison: String) async {
        // « révoqué » : ce nœud ne reconnaît plus cet appareil. Les autres nœuds restent utilisables.
        guard let visé = noeudDeCanal(canal) else { return }
        await ecarterPour(visé, oublier: raison == MotifsRevocation.noeud)
    }

    func recevoir(canal: String, message: ProtocoleAiguilleur.DuLien) async {
        switch message {
        case let .apiReponse(ref, statut, corps, codage, type, morceaux):
            guard let complet = corpsComplet(ref, corps, morceaux) else {
                await fluxes.echouer(ref, ErreurAiguilleur("transfert de la réponse interrompu"))
                return await requetes.echouer(ref, ErreurAiguilleur("transfert de la réponse interrompu"))
            }
            let octets = codage == "base64" ? Data(base64Encoded: complet) : Data(complet.utf8)
            if let octets, await fluxes.entier(ref, statut: statut, type: type, octets: octets) { return }
            await requetes.resoudre(ref, ReponseRequete(statut: statut, corps: complet, codage: codage, type: type))
        case let .apiFlux(ref, statut, type):
            _ = await fluxes.ouvrir(ref, statut: statut, type: type)
        case let .apiFin(ref, morceaux, ok):
            await fluxes.fin(ref, morceaux: morceaux, ok: ok)
        case let .morceau(ref, rang, corps):
            if await fluxes.morceau(ref, rang: rang, base64: corps) { return }
            _ = reassemblage.recevoir(ref: ref, rang: rang, corps: corps)
        case .revocation:
            // Révocation par un nœud : seul ce nœud est oublié ; le lien vers les autres reste ouvert.
            if let visé = noeudDeCanal(canal) { await ecarterPour(visé, oublier: true) }
        case .diffusionOuverte:
            diffusion?.yield(.ouverte)
        case let .diffusion(ref, corps, morceaux):
            guard let complet = corpsComplet(ref, corps, morceaux) else { return }
            recevoirDiffusion(complet, noeud: noeudDeCanal(canal))
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
        let courant = canal == canalCourant
        Trace.info("aiguilleur", "canal \(canal) terminé (courant : \(courant))")
        canaux.removeValue(forKey: canal)
        canalParNoeud = canalParNoeud.filter { $0.value != canal }
        // Un canal d'un autre nœud ne coupe ni le lien ni les requêtes des autres nœuds : ses requêtes expirent seules.
        guard courant else { return }
        reassemblage.vider()
        await echouerEnVol(ErreurAiguilleur("le lien vers le nœud est fermé"))
        finirDiffusion("le lien vers le nœud est fermé")
        finirTerminaux("le lien vers le nœud est fermé")
        canalCourant = nil
        if !bloque { await surLien(.rechercheNoeud) }
        await publierNoeuds()
        planifierReprise()
    }
}
