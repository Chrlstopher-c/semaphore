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
        await refuserLien(raison)
    }

    func recevoir(canal: String, message: ProtocoleAiguilleur.DuLien) async {
        switch message {
        case let .apiReponse(ref, statut, corps):
            await requetes.resoudre(ref, ReponseRequete(statut: statut, corps: corps))
        case .revocation:
            await revoquer()
        case .api:
            return
        }
    }

    func canalFerme(canal: String) async {
        canaux.removeValue(forKey: canal)
        await requetes.echouerTout(ErreurAiguilleur("le lien vers le nœud est fermé"))
        guard canal == canalCourant else { return }
        canalCourant = nil
        if !bloque { await surLien(.rechercheNoeud) }
        planifierReprise()
    }

    /// Le nœud nous a retiré : le lien s'arrête et ne se rouvre plus.
    func revoquer() async {
        revoque = true
        await refuserLien("révoqué")
        for canal in Array(canaux.values) { await canal.surFermetureDistante() }
        if let tache = transport { await tache.fermer() }
    }
}
