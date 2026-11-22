import Foundation

// Responsabilité : la boucle du lien sortant — connexion, présence, choix du nœud, ouverture du canal, reprise
// après coupure (2 s, doublée jusqu'à 30 s). Les messages de l'aiguilleur vont aux canaux un à un, dans l'ordre.

extension ClientAiguilleur {
    func boucleLien() async {
        while !Task.isCancelled && !revoque {
            await surLien(.connexion)
            // La coupure se lit dans les états du lien ; l'erreur précise n'est pas remontée à l'appli.
            do {
                try await sessionLien()
            } catch is ErreurRevocation {
                return await revoquerLien()
            } catch {
                // coupure ordinaire : la boucle reprend
            }
            await coupureLien()
            guard !Task.isCancelled && !revoque else { return }
            try? await Task.sleep(for: delaiReprise)
            delaiReprise = min(delaiReprise * 2, delais.repriseMax)
        }
    }

    func sessionLien() async throws {
        guard let url = URL(string: etat.adresse) else { throw ErreurAiguilleur("adresse de l'aiguilleur invalide") }
        let tache = try fabrique(url, etat.jeton)
        transport = tache
        let mesure = VivaciteLiaison(intervalle: delais.vivaciteIntervalle, delaiPong: delais.vivaciteDelaiPong)
        vivaciteCourante = mesure
        relancerVeille(tache, mesure)
        defer { veilleLien?.cancel() }
        await surLien(.rechercheNoeud)
        while true {
            let message = try await tache.recevoir()
            await mesure.recu()
            await traiterAiguilleur(message)
        }
    }

    /// Veille du lien : un ping à chaque échéance. Pas de pong dans le délai = liaison morte : le lien est
    /// fermé, la boucle le refait. Le pong arrive sur un autre fil ; il passe par la minuterie partagée.
    func veillerLien(_ tache: any TransportAiguilleur, _ mesure: VivaciteLiaison) async {
        while !Task.isCancelled {
            switch await mesure.action() {
            case .rien:
                break
            case .ping:
                await mesure.pingPartie()
                await tache.sonder(surPong: { Task { await mesure.recu() } })
            case .morte:
                Trace.info("aiguilleur", "liaison morte : aucun pong de l'aiguilleur, reconnexion")
                await tache.fermer()
                return
            }
            try? await Task.sleep(for: await mesure.attente())
        }
    }

    func relancerVeille(_ tache: any TransportAiguilleur, _ mesure: VivaciteLiaison) {
        veilleLien?.cancel()
        veilleLien = Task { await self.veillerLien(tache, mesure) }
    }

    /// Premier plan : un ping tout de suite ; sans pong dans le délai, le lien est refait.
    public func verifier() async {
        guard let tache = transport, let mesure = vivaciteCourante else { return }
        await mesure.forcerPing()
        relancerVeille(tache, mesure)
    }

    /// Changement de réseau : le lien courant est fermé, la boucle le refait sans attendre la reprise. Sans lien
    /// ouvert (reprise en cours), rien à faire : la reprise suivante part de nouveau.
    public func reconnecter() async {
        guard let tache = transport else { return }
        delaiReprise = delais.repriseInitiale
        await tache.fermer()
    }

    func coupureLien() async {
        if let tache = transport { await tache.fermer() }
        transport = nil
        for canal in Array(canaux.values) { await canal.surFermetureDistante() }
        finirDiffusion("lien avec l'aiguilleur coupé")
        finirTerminaux("lien avec l'aiguilleur coupé")
        await echouerEnVol(ErreurAiguilleur("lien avec l'aiguilleur coupé"))
        if !bloque { await surLien(.deconnecte) }
    }

    /// L'appareil est révoqué (par l'aiguilleur, fermeture 4401, ou par le nœud) : rien ne se rouvre, l'état le dit.
    func revoquerLien() async {
        revoque = true
        bloque = true
        await surLien(.revoque)
        if let tache = transport { await tache.fermer() }
        transport = nil
        for canal in Array(canaux.values) { await canal.surFermetureDistante() }
        canaux = [:]
        canalCourant = nil
        finirDiffusion("appareil révoqué")
        finirTerminaux("appareil révoqué")
        await echouerEnVol(ErreurAiguilleur("appareil révoqué"))
    }

    func traiterAiguilleur(_ message: ProtocoleAiguilleur.DeAiguilleur) async {
        switch message {
        case let .presence(membres): await surPresence(membres)
        case let .ouvrir(canal, _): await envoyerAiguilleur(.refuser(canal: canal))
        case let .accepter(canal): await canaux[canal]?.surAccepter()
        case let .refuser(canal): await canaux[canal]?.surRefus()
        case let .fermer(canal):
            Trace.info("aiguilleur", "canal \(canal) fermé par le nœud")
            await canaux[canal]?.surFermetureDistante()
        case let .donnees(canal, charge): await canaux[canal]?.surDonnees(charge)
        case let .erreur(canal, motif):
            await surErreur(canal, motif)
        }
    }

    func surPresence(_ membres: [ProtocoleAiguilleur.Membre]) async {
        delaiReprise = delais.repriseInitiale
        presence = membres
        await cibler()
    }

    /// Recalcule le nœud visé (préféré, appairé en ligne, sans écran d'abord) ; change de nœud si besoin, puis ouvre.
    func cibler() async {
        let choisi = SelectionNoeud.choisir(presence, moi: etat.membre, appaires: etat.appaires,
                                            prefere: etat.prefere, refuses: refuses)
        if choisi != etat.noeud {
            await fermerCanalCourant()
            etat.noeud = choisi
            await surEtat(etat)
        }
        await publierNoeuds()
        await ouvrirVersNoeud()
    }

    /// Ferme le canal en cours sans relancer la boucle : la cible change, le suivant est ouvert par `cibler`.
    func fermerCanalCourant() async {
        guard let id = canalCourant else { return }
        canalCourant = nil
        guard let canal = canaux[id] else { return }
        await canal.fermer()
    }

    /// Les nœuds vus, tels que les réglages les montrent (en ligne, appairé, sans écran, préféré, relié).
    func publierNoeuds() async {
        let vus = presence.filter { $0.genre == "noeud" && $0.id != etat.membre }.map { m in
            NoeudVu(
                id: m.id, nom: m.nom ?? etat.noeuds[m.id]?.nom ?? "Nœud", enLigne: m.enLigne,
                sansEcran: m.sansEcran == true, appaire: etat.estAppaire(m.id), prefere: etat.prefere == m.id,
                actif: canalCourant != nil && etat.noeud == m.id
            )
        }
        await surNoeuds(vus)
    }

    /// Ouvre le canal vers le nœud choisi, s'il est en ligne et qu'aucun canal n'est déjà ouvert ou en cours.
    func ouvrirVersNoeud() async {
        guard let noeud = etat.noeud, transport != nil, canalCourant == nil, !bloque else { return }
        guard presence.contains(where: { $0.id == noeud && $0.enLigne }) else {
            await surLien(.rechercheNoeud)
            return
        }
        guard let moi else { return await refuserLien("identité locale illisible") }
        let intention: Chiffrement.CanalAppareil.Intention = etat.estAppaire(noeud) ? .lien : .appairage
        let id = UUID().uuidString.lowercased()
        let canal = Chiffrement.CanalAppareil(
            id: id, membre: noeud, intention: intention, moi: moi, nomLocal: nomAppareil, hote: self
        )
        canaux[id] = canal
        canalCourant = id
        if intention == .appairage {
            await surLien(.attenteAccord(empreinte: graines.empreinte))
        } else {
            await surLien(.connexion)
        }
        await canal.ouvrir()
    }

    /// Un canal que l'aiguilleur signale en erreur (nœud hors ligne, canal inconnu) se ferme ; la reprise suit.
    func surErreur(_ canal: String?, _ motif: String) async {
        Trace.info("aiguilleur", "erreur de l'aiguilleur (\(canal ?? "lien")) : \(motif)")
        guard let canal else {
            return await echouerEnVol(ErreurAiguilleur("aiguilleur : \(motif)"))
        }
        await canaux[canal]?.surFermetureDistante()
    }

    /// Réouvre le canal après un délai (la cible est recalculée) ; sans effet si le lien est coupé ou bloqué.
    func planifierReprise() {
        guard !bloque, transport != nil else { return }
        let delai = delaiReprise
        delaiReprise = min(delaiReprise * 2, delais.repriseMax)
        Task {
            try? await Task.sleep(for: delai)
            await self.cibler()
        }
    }

    /// Un nœud refuse le lien ou l'a révoqué : il est exclu de la sélection, les autres restent disponibles.
    func ecarterNoeud(_ id: String, oublier: Bool) async {
        refuses.insert(id)
        if oublier {
            etat.noeuds[id] = nil
            await surEtat(etat)
        }
        await fermerCanalCourant()
        planifierReprise()
    }

    func refuserLien(_ raison: String) async {
        bloque = true
        await surLien(.refuse(raison))
    }
}
