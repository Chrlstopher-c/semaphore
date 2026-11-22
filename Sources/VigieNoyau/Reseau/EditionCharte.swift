import Foundation

// Responsabilité : les éditions de la charte, pures. Chacune rend la charte SUIVANTE, non signée (version + 1,
// auteur = `par`, date = `le`). Mêmes règles et refus que `commun/charte.ts` ; l'édition porte sur le JSON brut,
// donc un champ inconnu d'une version plus récente reste tel quel.

public enum EditionCharte {
    public static func nommerChef(_ c: CharteReseau, auteur: String, membre: String, chef: Bool, le: String) throws
        -> CharteReseau
    {
        try exigerChef(c, auteur)
        guard let cible = c.membre(membre) else { throw refus("membre absent") }
        if chef && cible.sorte == .serveur { throw refus("un serveur ne peut pas être chef") }
        if chef && cible.invite != nil { throw refus("un invité ne peut pas être chef") }
        if !chef && membre == auteur { throw refus("un chef ne retire pas son propre rôle") }
        let chefs = chef ? ajouterUnique(c.chefs, membre) : c.chefs.filter { $0 != membre }
        return try suivante(c, auteur: auteur, le: le, membres: c.membresBrut, chefs: chefs)
    }

    /// Droits, compte et nom d'un membre. `compte` : nil = inchangé, `.some(nil)` = sans compte.
    public static func changerMembre(
        _ c: CharteReseau, auteur: String, membre: String, droits: DroitsMembre?, compte: String??, nom: String?,
        le: String
    ) throws -> CharteReseau {
        try exigerChef(c, auteur)
        guard let cible = c.membre(membre) else { throw refus("membre absent") }
        if droits != nil && cible.invite != nil { throw refus("droits d'un invité : régler ses limites") }
        let membres = membresAvec(c, membre) { objet in
            var modifie = objet
            if let droits { modifie["droits"] = droits.valeurJSON }
            if let compte { modifie["compte"] = compte.map { ValeurJSON.texte($0) } ?? .nul }
            if let nom { modifie["nom"] = .texte(nomValide(nom, membre)) }
            return modifie
        }
        return try suivante(c, auteur: auteur, le: le, membres: membres, chefs: c.chefs)
    }

    /// Retire un membre ; la machine retirée est ôtée des réglages de ses invités (sinon la charte ne se relit
    /// plus).
    public static func retirerMembre(_ c: CharteReseau, auteur: String, membre: String, le: String) throws
        -> CharteReseau
    {
        try exigerChef(c, auteur)
        guard c.membre(membre) != nil else { throw refus("membre absent") }
        let chefs = c.chefs.filter { $0 != membre }
        if chefs.isEmpty { throw refus("dernier chef") }
        if membre == auteur { throw refus("un chef ne se retire pas lui-même") }
        let restants = c.membresBrut.filter { identifiantDe($0) != membre }.map { sansMachine($0, machine: membre) }
        return try suivante(c, auteur: auteur, le: le, membres: restants, chefs: chefs)
    }

    /// Ajoute un membre plein : tous les droits, sans compte.
    public static func ajouterMembre(
        _ c: CharteReseau, auteur: String, id: String, nom: String, sorte: SorteMembre, identite: String, le: String
    ) throws -> CharteReseau {
        try exigerChef(c, auteur)
        if c.membre(id) != nil { throw refus("déjà membre") }
        let membre = ValeurJSON.objet([
            "id": .texte(id), "nom": .texte(nomValide(nom, id)), "sorte": .texte(sorte.rawValue),
            "identite": .texte(identite), "droits": DroitsMembre.tous.valeurJSON, "compte": .nul,
        ])
        return try suivante(c, auteur: auteur, le: le, membres: c.membresBrut + [membre], chefs: c.chefs)
    }

    /// Invite un membre : nouveau (pair invité) ou pair existant (devient invité). Chef, téléphone, serveur exclus.
    public static func inviterMembre(
        _ c: CharteReseau, auteur: String, id: String, nom: String, identite: String, reglages: ReglagesInvite,
        le: String
    ) throws -> CharteReseau {
        try exigerChef(c, auteur)
        let existant = c.membre(id)
        if existant != nil && c.estChef(id) { throw refus("un chef ne peut pas être invité") }
        if let existant, existant.sorte != .pair { throw refus("seul un pair peut être invité") }
        try validerReglages(c, idInvite: id, reglages)
        guard existant != nil else {
            let membre = ValeurJSON.objet([
                "id": .texte(id), "nom": .texte(nomValide(nom, id)), "sorte": .texte(SorteMembre.pair.rawValue),
                "identite": .texte(identite), "droits": DroitsMembre.aucun.valeurJSON, "compte": .nul,
                "invite": reglages.valeurJSON,
            ])
            return try suivante(c, auteur: auteur, le: le, membres: c.membresBrut + [membre], chefs: c.chefs)
        }
        let membres = membresAvec(c, id) { objet in
            let paires = ["droits": DroitsMembre.aucun.valeurJSON, "invite": reglages.valeurJSON]
            return objet.merging(paires) { _, nouveau in nouveau }
        }
        return try suivante(c, auteur: auteur, le: le, membres: membres, chefs: c.chefs)
    }

    /// Change les réglages d'un invité ; ses droits de base restent à aucun.
    public static func changerInvite(
        _ c: CharteReseau, auteur: String, membre: String, reglages: ReglagesInvite, le: String
    ) throws -> CharteReseau {
        try exigerChef(c, auteur)
        guard let cible = c.membre(membre) else { throw refus("membre absent") }
        guard cible.invite != nil else { throw refus("membre non invité") }
        try validerReglages(c, idInvite: membre, reglages)
        let membres = membresAvec(c, membre) { objet in
            objet.merging(["invite": reglages.valeurJSON]) { _, nouveau in nouveau }
        }
        return try suivante(c, auteur: auteur, le: le, membres: membres, chefs: c.chefs)
    }

    /// Horodatage ISO 8601 avec millisecondes et `Z`, comme `new Date().toISOString()`.
    public static func horodatage(_ date: Date = Date()) -> String {
        let formateur = ISO8601DateFormatter()
        formateur.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formateur.string(from: date)
    }

    // MARK: - Règles communes

    private static func exigerChef(_ c: CharteReseau, _ auteur: String) throws {
        guard c.estChef(auteur) else { throw refus("auteur non chef") }
    }

    private static func refus(_ raison: String) -> ErreurReseau { ErreurReseau(message: raison) }

    private static func validerReglages(_ c: CharteReseau, idInvite: String, _ reglages: ReglagesInvite) throws {
        if reglages.defaut() != nil { throw refus("réglages invalides") }
        for machine in reglages.machines {
            if let raison = raisonMachine(c, idInvite: idInvite, machine) { throw refus(raison) }
        }
    }

    private static func raisonMachine(_ c: CharteReseau, idInvite: String, _ machine: String) -> String? {
        if machine == idInvite { return "un invité ne peut pas être sa propre machine" }
        guard let cible = c.membre(machine) else { return "machine inconnue : \(machine)" }
        let permise = cible.invite == nil && (cible.sorte == .serveur || cible.sorte == .pair)
        return permise ? nil : "machine non permise : \(machine)"
    }

    /// La charte suivante : version + 1, auteur, date, membres et chefs ; le reste du JSON est gardé.
    private static func suivante(_ c: CharteReseau, auteur: String, le: String, membres: [ValeurJSON], chefs: [String])
        throws -> CharteReseau
    {
        var objet = c.objetBrut
        objet["version"] = .nombre(Double(c.version + 1))
        objet["par"] = .texte(auteur)
        objet["le"] = .texte(le)
        objet["membres"] = .tableau(membres)
        objet["chefs"] = .tableau(chefs.map { ValeurJSON.texte($0) })
        return try CharteReseau(brut: .objet(objet))
    }

    /// Les membres du JSON brut, avec `transforme` appliqué au seul membre `id`.
    private static func membresAvec(
        _ c: CharteReseau, _ id: String, _ transforme: ([String: ValeurJSON]) -> [String: ValeurJSON]
    ) -> [ValeurJSON] {
        c.membresBrut.map { valeur in
            guard case .objet(let objet) = valeur, identifiantDe(valeur) == id else { return valeur }
            return .objet(transforme(objet))
        }
    }

    private static func identifiantDe(_ valeur: ValeurJSON) -> String? {
        guard case .texte(let id)? = valeur["id"] else { return nil }
        return id
    }

    /// Ôte `machine` de la liste `invite.machines` du membre, si présente.
    private static func sansMachine(_ valeur: ValeurJSON, machine: String) -> ValeurJSON {
        guard case .objet(var objet) = valeur, case .objet(var invite)? = objet["invite"],
            case .tableau(let machines)? = invite["machines"]
        else { return valeur }
        invite["machines"] = .tableau(machines.filter { $0 != ValeurJSON.texte(machine) })
        objet["invite"] = .objet(invite)
        return .objet(objet)
    }

    private static func ajouterUnique(_ liste: [String], _ element: String) -> [String] {
        liste.contains(element) ? liste : liste + [element]
    }

    /// Nom net : rogné, 80 caractères au plus ; vide → repli (comme `nomValide` du serveur).
    private static func nomValide(_ nom: String, _ repli: String) -> String {
        let net = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        let rogne = String(decoding: Array(net.utf16.prefix(80)), as: UTF16.self)
        return rogne.isEmpty ? repli : rogne
    }
}
