import Foundation

// Responsabilité : le parc vu depuis l'iPhone (réseau v3 §7). Un canal ouvert vers chaque nœud appairé en ligne ; une
// requête sur une session part au nœud qui la tient ; la liste du parc est l'union des sessions locales de chaque
// nœud (`/api/etat?local=1`), chaque session étiquetée par son nœud. Le nœud de création et d'appairage reste la cible
// du lien (`etat.noeud`).

extension ClientAiguilleur {
    /// Le nœud qui tient la session visée par un chemin `/api/sessions/<id>/…`, appris de la liste ; nil sinon.
    func noeudDeChemin(_ chemin: String) -> String? {
        let sansRequete = chemin.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let morceaux = (sansRequete.first ?? "").split(separator: "/")
        guard morceaux.count >= 3, morceaux[0] == "api", morceaux[1] == "sessions" else { return nil }
        return sessionsNoeud[String(morceaux[2])]
    }

    /// Le canal ouvert vers ce nœud ; sans nœud, la cible du lien. Un nœud sans canal ouvert donne nil.
    func canalAdresse(noeud: String?) async -> Chiffrement.CanalAppareil? {
        let id: String?
        if let noeud { id = canalParNoeud[noeud] } else { id = canalCourant }
        guard let id, let canal = canaux[id], await canal.estOuvert else { return nil }
        return canal
    }

    /// Ouvre un canal vers `noeud`. `cible` : ce nœud porte le lien (appairage ou création), il tient `canalCourant`.
    func ouvrirCanal(
        _ noeud: String, intention: Chiffrement.CanalAppareil.Intention, moi: Chiffrement.Identite, cible: Bool
    ) async {
        let id = UUID().uuidString.lowercased()
        let canal = Chiffrement.CanalAppareil(
            id: id, membre: noeud, intention: intention, moi: moi, nomLocal: nomAppareil, hote: self
        )
        canaux[id] = canal
        canalParNoeud[noeud] = id
        if cible { canalCourant = id }
        await canal.ouvrir()
    }

    /// Un canal vers chaque autre nœud appairé et en ligne. Sans accord humain, jamais d'appairage ici.
    func ouvrirAuxAutres() async {
        guard transport != nil, !bloque, let moi else { return }
        let cibles = presence.filter {
            $0.genre == "noeud" && $0.enLigne && $0.id != etat.membre && $0.id != etat.noeud
                && etat.estAppaire($0.id) && !refuses.contains($0.id) && canalParNoeud[$0.id] == nil
        }
        for membre in cibles {
            await ouvrirCanal(membre.id, intention: .lien, moi: moi, cible: false)
        }
    }

    /// Le nœud auquel appartient ce canal, ou nil.
    func noeudDeCanal(_ canal: String) -> String? {
        canalParNoeud.first { $0.value == canal }?.key
    }

    /// Refus ou révocation d'un nœud : la cible passe par `ecarterNoeud` (elle porte le lien), un autre par `ecarterAutre`.
    func ecarterPour(_ noeud: String, oublier: Bool) async {
        if noeud == etat.noeud {
            await ecarterNoeud(noeud, oublier: oublier)
        } else {
            await ecarterAutre(noeud, oublier: oublier)
        }
    }

    /// Un nœud autre que la cible qui refuse ou révoque : il est exclu de la sélection, son canal se ferme.
    func ecarterAutre(_ noeud: String, oublier: Bool) async {
        refuses.insert(noeud)
        if oublier {
            etat.noeuds[noeud] = nil
            await surEtat(etat)
        }
        if let id = canalParNoeud[noeud], let canal = canaux[id] { await canal.fermer() }
    }

    /// La liste du parc : `/api/etat?local=1` sur chaque canal ouvert ; sessions et machines réunies, chaque session
    /// rangée sous son nœud. Le reste de la réponse (notifications, découvertes) vient de la cible, sinon du premier.
    func etatDuParc(delai: Duration?) async throws -> ReponseRequete {
        _ = try await canalOuvert()
        var ouverts: [String] = []
        for noeud in canalParNoeud.keys.sorted() {
            if await canalAdresse(noeud: noeud) != nil { ouverts.append(noeud) }
        }
        if let cible = etat.noeud, let rang = ouverts.firstIndex(of: cible) { ouverts.swapAt(0, rang) }
        var reponses: [(noeud: String, objet: [String: Any])] = []
        for noeud in ouverts {
            guard let r = try? await requeteDansCanal(
                methode: "GET", chemin: "/api/etat?local=1", corps: nil, codage: nil, type: nil, noeud: noeud, delai: delai
            ), r.statut == 200, let octets = r.corps.data(using: .utf8),
                let objet = try? JSONSerialization.jsonObject(with: octets) as? [String: Any] else { continue }
            reponses.append((noeud, objet))
        }
        guard var corps = reponses.first?.objet else { throw ErreurAiguilleur("aucun nœud n'a rendu sa liste") }
        var sessions: [[String: Any]] = []
        var machines: [[String: Any]] = []
        var vuesSessions = Set<String>()
        var vuesMachines = Set<String>()
        for (noeud, objet) in reponses {
            for var session in (objet["sessions"] as? [[String: Any]]) ?? [] {
                guard let id = session["id"] as? String, !vuesSessions.contains(id) else { continue }
                vuesSessions.insert(id)
                session["noeud"] = noeud
                sessionsNoeud[id] = noeud
                sessions.append(session)
            }
            for machine in (objet["machines"] as? [[String: Any]]) ?? [] {
                guard let id = machine["id"] as? String, !vuesMachines.contains(id) else { continue }
                vuesMachines.insert(id)
                machines.append(machine)
            }
        }
        corps["sessions"] = sessions
        corps["machines"] = machines
        guard let octets = try? JSONSerialization.data(withJSONObject: corps) else {
            throw ErreurAiguilleur("liste du parc non rendue")
        }
        return ReponseRequete(statut: 200, corps: String(decoding: octets, as: UTF8.self))
    }
}
