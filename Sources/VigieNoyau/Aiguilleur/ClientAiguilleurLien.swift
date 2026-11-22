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
        await surLien(.rechercheNoeud)
        while true {
            await traiterAiguilleur(try await tache.recevoir())
        }
    }

    func coupureLien() async {
        if let tache = transport { await tache.fermer() }
        transport = nil
        for canal in Array(canaux.values) { await canal.surFermetureDistante() }
        finirDiffusion("lien avec l'aiguilleur coupé")
        finirTerminaux("lien avec l'aiguilleur coupé")
        await requetes.echouerTout(ErreurAiguilleur("lien avec l'aiguilleur coupé"))
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
        await requetes.echouerTout(ErreurAiguilleur("appareil révoqué"))
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
        if etat.noeud == nil {
            guard let choisi = SelectionNoeud.choisir(membres, moi: etat.membre) else {
                return await surLien(.rechercheNoeud)
            }
            etat.noeud = choisi
            await surEtat(etat)
        }
        await ouvrirVersNoeud()
    }

    /// Ouvre le canal vers le nœud choisi, s'il est en ligne et qu'aucun canal n'est déjà ouvert ou en cours.
    func ouvrirVersNoeud() async {
        guard let noeud = etat.noeud, transport != nil, canalCourant == nil, !bloque else { return }
        guard presence.contains(where: { $0.id == noeud && $0.enLigne }) else { return await surLien(.rechercheNoeud) }
        guard let moi else { return await refuserLien("identité locale illisible") }
        let intention: Chiffrement.CanalAppareil.Intention = etat.identiteNoeud == nil ? .appairage : .lien
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
            return await requetes.echouerTout(ErreurAiguilleur("aiguilleur : \(motif)"))
        }
        await canaux[canal]?.surFermetureDistante()
    }

    /// Réouvre le canal après un délai ; sans effet si le lien est coupé ou bloqué entre-temps.
    func planifierReprise() {
        guard !bloque, transport != nil else { return }
        let delai = delaiReprise
        delaiReprise = min(delaiReprise * 2, delais.repriseMax)
        Task {
            try? await Task.sleep(for: delai)
            await self.ouvrirVersNoeud()
        }
    }

    func refuserLien(_ raison: String) async {
        bloque = true
        await surLien(.refuse(raison))
    }
}
