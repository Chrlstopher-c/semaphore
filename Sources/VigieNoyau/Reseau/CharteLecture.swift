import Foundation

// Responsabilité : la lecture et la cohérence d'une charte (format, bornes, chefs, invités), miroir de
// `commun/charte.ts` (`coherence`, `invitePermis`). Pur : ni signature, ni E/S.

/// Les champs typés d'une charte, lus et vérifiés d'un bloc.
struct ChampsCharte {
    let reseau: String
    let nom: String
    let version: Int
    let chefs: [String]
    let membres: [MembreCharte]
    let le: String
    let par: String
    let origine: String

    static func lire(_ valeur: ValeurJSON) throws -> ChampsCharte {
        let objet = try Lu.objet(valeur, "racine")
        guard try Lu.entier(objet["format"], "format") == 1 else { throw Lu.illisible("format") }
        let champs = ChampsCharte(
            reseau: try Lu.identifiant(objet["reseau"], "reseau"), nom: try Lu.nom(objet["nom"], "nom"),
            version: try Lu.entierDans(objet["version"], "version", 1...Int.max), chefs: try lireChefs(objet["chefs"]),
            membres: try lireMembres(objet["membres"]), le: try Lu.texteMax(objet["le"], "le", 40),
            par: try Lu.identifiant(objet["par"], "par"), origine: try lireOrigine(objet["origine"]))
        try champs.verifierCoherence()
        return champs
    }

    func membre(_ id: String) -> MembreCharte? { membres.first { $0.id == id } }

    /// Doublons, chefs (pair ou téléphone, jamais invité ni serveur), invités permis, signataire chef.
    func verifierCoherence() throws {
        let ids = membres.map(\.id)
        guard Set(ids).count == ids.count, Set(chefs).count == chefs.count else { throw Lu.illisible("doublon") }
        for chef in chefs {
            guard let cible = membre(chef), cible.sorte != .serveur, cible.invite == nil else {
                throw Lu.illisible("chef invalide")
            }
        }
        for candidat in membres where candidat.invite != nil && !invitePermis(candidat) {
            throw Lu.illisible("invité non permis")
        }
        guard chefs.contains(par) else { throw Lu.illisible("signataire non chef") }
    }

    /// Un invité est un pair sans droit de base, dont chaque machine est un membre non invité, serveur ou pair.
    private func invitePermis(_ candidat: MembreCharte) -> Bool {
        guard let invite = candidat.invite, candidat.sorte == .pair, candidat.droits == DroitsMembre.aucun else {
            return false
        }
        return invite.machines.allSatisfy { id in
            guard let cible = membre(id) else { return false }
            return cible.invite == nil && (cible.sorte == .serveur || cible.sorte == .pair)
        }
    }

    private static func lireChefs(_ valeur: ValeurJSON?) throws -> [String] {
        let chefs = try Lu.tableau(valeur, "chefs").map { try Lu.identifiant($0, "chefs") }
        guard (1...20).contains(chefs.count) else { throw Lu.illisible("chefs") }
        return chefs
    }

    private static func lireMembres(_ valeur: ValeurJSON?) throws -> [MembreCharte] {
        let membres = try Lu.tableau(valeur, "membres").map { try MembreCharte.lire($0) }
        guard membres.count <= 200 else { throw Lu.illisible("membres") }
        return membres
    }

    private static func lireOrigine(_ valeur: ValeurJSON?) throws -> String {
        let origine = try Lu.texte(valeur, "origine")
        guard origine == "creation" || origine == "reprise" else { throw Lu.illisible("origine") }
        return origine
    }
}
