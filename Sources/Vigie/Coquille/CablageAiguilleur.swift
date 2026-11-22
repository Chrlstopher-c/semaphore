// Le transport « par l'aiguilleur » : identité de l'iPhone générée une fois (trousseau), appairage par code à
// l'aiguilleur, acceptation de l'iPhone par Chris sur son nœud (empreinte comparée), puis l'API clients dans le canal
// chiffré. Le reste de l'appli ne voit qu'un `ClientRelais` : direct ou par l'aiguilleur, même API.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

extension Cablage {
    private static let nomIPhone = "iPhone (Quart)"
    private static let cleNom = "quart.aiguilleur.nom"

    /// Le nom donné à l'iPhone au dernier appairage (montré au nœud quand il présente sa demande).
    static var nomRetenu: String {
        let n = UserDefaults.standard.string(forKey: cleNom) ?? ""
        return n.isEmpty ? nomIPhone : n
    }

    /// L'identité de l'iPhone : générée à la première demande, gardée dans le trousseau (jamais exportée ailleurs).
    static func graines() -> GrainesIdentite {
        if let brut = Trousseau.lire(compte: Trousseau.compteIdentite),
           let g = try? JSONDecoder().decode(GrainesIdentite.self, from: Data(brut.utf8)) { return g }
        let neuves = GrainesIdentite.generer()
        if let json = try? JSONEncoder().encode(neuves) {
            Trousseau.ecrire(String(decoding: json, as: UTF8.self), compte: Trousseau.compteIdentite)
        }
        return neuves
    }

    /// Empreinte de l'iPhone (16 groupes de 4), à comparer avec celle que montre le nœud.
    public var empreinteAppareil: String { Self.graines().empreinte }

    static func etatAiguilleurGarde() -> ClientAiguilleur.Etat? {
        guard let brut = Trousseau.lire(compte: Trousseau.compteAiguilleur) else { return nil }
        return try? JSONDecoder().decode(ClientAiguilleur.Etat.self, from: Data(brut.utf8))
    }

    private static func garder(_ etat: ClientAiguilleur.Etat?) {
        let json = etat.flatMap { try? JSONEncoder().encode($0) }.map { String(decoding: $0, as: UTF8.self) }
        Trousseau.ecrire(json, compte: Trousseau.compteAiguilleur)
    }

    /// Appairage à l'aiguilleur par code (10 min, usage unique) ; la demande part ensuite vers le nœud.
    public func appairerAiguilleur(adresse: URL, code: String, nom: String) async throws {
        let propre = nom.trimmingCharacters(in: .whitespaces)
        let etat = try await ClientAiguilleur.appairer(adresse: adresse, code: code,
                                                       nom: propre.isEmpty ? Self.nomIPhone : propre,
                                                       graines: Self.graines())
        UserDefaults.standard.set(propre, forKey: Self.cleNom)
        Self.garder(etat)
        brancherAiguilleur(etat)
    }

    /// Branche le client de l'aiguilleur. L'appli ne bascule sur la liste qu'une fois le nœud accepté.
    func brancherAiguilleur(_ etat: ClientAiguilleur.Etat) {
        let client = ClientAiguilleur(
            etat: etat, graines: Self.graines(), nomAppareil: Self.nomRetenu,
            surEtat: { [weak self] nouveau in await self?.recevoirEtat(nouveau) },
            surLien: { [weak self] lien in await self?.recevoirLien(lien) })
        let ancien = clientAiguilleur // capturé AVANT le remplacement : sinon c'est le nouveau qu'on arrêterait
        Task { await ancien?.arreter() }
        clientAiguilleur = client
        etatAiguilleur = etat
        Task { await client.demarrer() }
        if etat.identiteNoeud != nil, let url = URL(string: etat.adresse) {
            brancher(client: ClientRelais(adresse: url, jeton: "", aiguilleur: client))
        } else if !connecte {
            // En attente d'acceptation : la liaison directe reste en service si elle existe, rien n'est perdu.
            brancher(jeton: Trousseau.lire())
        }
    }

    private func recevoirEtat(_ etat: ClientAiguilleur.Etat) {
        let accepte = etatAiguilleur?.identiteNoeud == nil && etat.identiteNoeud != nil
        etatAiguilleur = etat
        Self.garder(etat)
        guard accepte, let client = clientAiguilleur, let url = URL(string: etat.adresse) else { return }
        Trousseau.ecrire(nil) // le nœud a accepté l'iPhone : la clé directe n'a plus lieu d'être
        brancher(client: ClientRelais(adresse: url, jeton: "", aiguilleur: client))
    }

    private func recevoirLien(_ lien: ClientAiguilleur.Lien) {
        if lienAiguilleur != lien { lienAiguilleur = lien }
    }

    /// Annule une demande vers le Pi pas encore acceptée : la liaison en service (directe) reste telle quelle.
    public func annulerAiguilleur() {
        guard etatAiguilleur?.identiteNoeud == nil else { return }
        oublierAiguilleur()
        if !connecte { brancher(jeton: Trousseau.lire()) }
    }

    /// Abandonne le lien par l'aiguilleur (déconnexion, retour au direct) : l'identité de l'iPhone reste.
    func oublierAiguilleur() {
        let client = clientAiguilleur
        clientAiguilleur = nil
        etatAiguilleur = nil
        lienAiguilleur = .deconnecte
        Self.garder(nil)
        Task { await client?.arreter() }
    }
}
#endif
