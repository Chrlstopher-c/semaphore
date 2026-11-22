import Foundation
import Testing

@testable import VigieNoyau

// Les éditions de la charte : chaque règle de `commun/charte.ts` a son cas accepté et son refus, et un champ inconnu
// d'une version plus récente survit à l'édition.

private let telephone = "7777bbbb8888"
private let le = "2026-11-22T11:00:00.000Z"

private func cle() -> Chiffrement.Identite { Chiffrement.Identite.generer() }

private func charte(_ membres: [ValeurJSON], chefs: [String] = [FabriqueCharte.chef]) throws -> CharteReseau {
    try CharteReseau(brut: FabriqueCharte.charte(version: 1, chefs: chefs, par: chefs[0], membres: membres))
}

private func charteDeBase(chefs: [String] = [FabriqueCharte.chef]) throws -> CharteReseau {
    try charte(
        [
            FabriqueCharte.membre(FabriqueCharte.chef, .pair, cle()),
            FabriqueCharte.membre(FabriqueCharte.serveur, .serveur, cle()),
            FabriqueCharte.membre(FabriqueCharte.pair, .pair, cle(), droits: .aucun),
            FabriqueCharte.membre(telephone, .telephone, cle()),
        ], chefs: chefs)
}

private func charteAvecInvite(machines: [String]) throws -> CharteReseau {
    let reglages = ReglagesInvite.parDefaut(machine: nil)
    var avec = reglages
    avec.machines = machines
    return try charte([
        FabriqueCharte.membre(FabriqueCharte.chef, .pair, cle()),
        FabriqueCharte.membre(FabriqueCharte.serveur, .serveur, cle()),
        FabriqueCharte.membre(FabriqueCharte.invite, .pair, cle(), droits: .aucun, invite: avec),
    ])
}

/// Le motif du refus (le message de l'erreur), ou nil si l'édition passe.
private func refus(_ edition: () throws -> CharteReseau) -> String? {
    do {
        _ = try edition()
        return nil
    } catch let erreur as ErreurReseau { return erreur.message } catch { return "autre erreur : \(error)" }
}

struct EditionCharteReseauTests {
    @Test func nommerChefPromeutUnPairEtPasseLaVersionSuivante() throws {
        let c = try charteDeBase()
        let suivante = try EditionCharte.nommerChef(
            c, auteur: FabriqueCharte.chef, membre: FabriqueCharte.pair, chef: true, le: le)
        #expect(suivante.chefs == [FabriqueCharte.chef, FabriqueCharte.pair])
        #expect(suivante.version == 2)
        #expect(suivante.par == FabriqueCharte.chef)
        #expect(suivante.le == le)
    }

    @Test func nommerChefRefuseLesCasInterdits() throws {
        let c = try charteDeBase()
        let nonChef = refus {
            try EditionCharte.nommerChef(
                c, auteur: FabriqueCharte.pair, membre: FabriqueCharte.pair, chef: true, le: le)
        }
        let serveur = refus {
            try EditionCharte.nommerChef(
                c, auteur: FabriqueCharte.chef, membre: FabriqueCharte.serveur, chef: true, le: le)
        }
        let soiMeme = refus {
            try EditionCharte.nommerChef(
                c, auteur: FabriqueCharte.chef, membre: FabriqueCharte.chef, chef: false, le: le)
        }
        #expect(nonChef == "auteur non chef")
        #expect(serveur == "un serveur ne peut pas être chef")
        #expect(soiMeme == "un chef ne retire pas son propre rôle")
    }

    @Test func nommerChefRefuseUnInviteEtUnMembreAbsent() throws {
        let c = try charteAvecInvite(machines: [FabriqueCharte.serveur])
        let invite = refus {
            try EditionCharte.nommerChef(
                c, auteur: FabriqueCharte.chef, membre: FabriqueCharte.invite, chef: true, le: le)
        }
        let absent = refus {
            try EditionCharte.nommerChef(c, auteur: FabriqueCharte.chef, membre: telephone, chef: true, le: le)
        }
        #expect(invite == "un invité ne peut pas être chef")
        #expect(absent == "membre absent")
    }

    @Test func changerMembreModifieDroitsNomEtCompte() throws {
        let c = try charteDeBase()
        let suivante = try EditionCharte.changerMembre(
            c, auteur: FabriqueCharte.chef, membre: FabriqueCharte.pair, droits: .tous, compte: .some("compte-a"),
            nom: "  Nouveau nom  ", le: le)
        let modifie = try #require(suivante.membre(FabriqueCharte.pair))
        #expect(modifie.droits == .tous)
        #expect(modifie.compte == "compte-a")
        #expect(modifie.nom == "Nouveau nom")
    }

    @Test func changerMembreRefuseLesDroitsD_unInviteEtLesAbsents() throws {
        let c = try charteAvecInvite(machines: [FabriqueCharte.serveur])
        let droits = refus {
            try EditionCharte.changerMembre(
                c, auteur: FabriqueCharte.chef, membre: FabriqueCharte.invite, droits: .tous, compte: nil, nom: nil,
                le: le)
        }
        let absent = refus {
            try EditionCharte.changerMembre(
                c, auteur: FabriqueCharte.chef, membre: telephone, droits: nil, compte: nil, nom: nil, le: le)
        }
        #expect(droits == "droits d'un invité : régler ses limites")
        #expect(absent == "membre absent")
    }

    @Test func retirerMembreNettoieLesMachinesDesInvites() throws {
        let c = try charteAvecInvite(machines: [FabriqueCharte.serveur])
        let suivante = try EditionCharte.retirerMembre(
            c, auteur: FabriqueCharte.chef, membre: FabriqueCharte.serveur, le: le)
        let invite = try #require(suivante.membre(FabriqueCharte.invite))
        #expect(invite.invite?.machines == [])
        #expect(suivante.membre(FabriqueCharte.serveur) == nil)
    }

    @Test func retirerMembreRefuseLeDernierChefEtLaAutoSuppression() throws {
        let seul = try charteDeBase()
        let dernier = refus {
            try EditionCharte.retirerMembre(seul, auteur: FabriqueCharte.chef, membre: FabriqueCharte.chef, le: le)
        }
        let deux = try charteDeBase(chefs: [FabriqueCharte.chef, FabriqueCharte.pair])
        let soiMeme = refus {
            try EditionCharte.retirerMembre(deux, auteur: FabriqueCharte.chef, membre: FabriqueCharte.chef, le: le)
        }
        #expect(dernier == "dernier chef")
        #expect(soiMeme == "un chef ne se retire pas lui-même")
    }

    @Test func ajouterMembreDonneTousLesDroitsSansCompte() throws {
        let c = try charteDeBase()
        let suivante = try EditionCharte.ajouterMembre(
            c, auteur: FabriqueCharte.chef, id: "c0ffee000001", nom: "Neuf", sorte: .pair,
            identite: FabriqueCharte.texteIdentite(cle()), le: le)
        let ajoute = try #require(suivante.membre("c0ffee000001"))
        #expect(ajoute.droits == .tous)
        #expect(ajoute.compte == nil)
        #expect(
            refus {
                try EditionCharte.ajouterMembre(
                    c, auteur: FabriqueCharte.chef, id: FabriqueCharte.pair, nom: "x", sorte: .pair, identite: "x",
                    le: le)
            } == "déjà membre")
    }

    @Test func inviterUnNouveauMembreLuiDonneDesReglagesEtAucunDroit() throws {
        let c = try charteDeBase()
        let nouvel = "c0ffee000002"
        let suivante = try EditionCharte.inviterMembre(
            c, auteur: FabriqueCharte.chef, id: nouvel, nom: "Invite neuf",
            identite: FabriqueCharte.texteIdentite(cle()),
            reglages: ReglagesInvite.parDefaut(machine: FabriqueCharte.serveur), le: le)
        let invite = try #require(suivante.membre(nouvel))
        #expect(invite.sorte == .pair)
        #expect(invite.droits == .aucun)
        #expect(invite.invite?.machines == [FabriqueCharte.serveur])
    }

    @Test func inviterRefuseLesMembresInterdits() throws {
        let c = try charteDeBase()
        let identite = FabriqueCharte.texteIdentite(cle())
        let reglages = ReglagesInvite.parDefaut(machine: FabriqueCharte.serveur)
        let chef = refus {
            try EditionCharte.inviterMembre(
                c, auteur: FabriqueCharte.chef, id: FabriqueCharte.chef, nom: "x", identite: identite,
                reglages: reglages, le: le)
        }
        let serveur = refus {
            try EditionCharte.inviterMembre(
                c, auteur: FabriqueCharte.chef, id: FabriqueCharte.serveur, nom: "x", identite: identite,
                reglages: reglages, le: le)
        }
        #expect(chef == "un chef ne peut pas être invité")
        #expect(serveur == "seul un pair peut être invité")
    }

    @Test func inviterRefuseLesMachinesEtLesReglagesHorsBornes() throws {
        let c = try charteDeBase()
        let identite = FabriqueCharte.texteIdentite(cle())
        var hors = ReglagesInvite.parDefaut(machine: FabriqueCharte.serveur)
        hors.part5h = 150
        let bornes = refus {
            try EditionCharte.inviterMembre(
                c, auteur: FabriqueCharte.chef, id: "c0ffee000003", nom: "x", identite: identite, reglages: hors, le: le
            )
        }
        let telephoneMachine = refus {
            try EditionCharte.inviterMembre(
                c, auteur: FabriqueCharte.chef, id: "c0ffee000003", nom: "x", identite: identite,
                reglages: .parDefaut(machine: telephone), le: le)
        }
        let soiMeme = refus {
            try EditionCharte.inviterMembre(
                c, auteur: FabriqueCharte.chef, id: "c0ffee000003", nom: "x", identite: identite,
                reglages: .parDefaut(machine: "c0ffee000003"), le: le)
        }
        #expect(bornes == "réglages invalides")
        #expect(telephoneMachine == "machine non permise : \(telephone)")
        #expect(soiMeme == "un invité ne peut pas être sa propre machine")
    }

    @Test func changerInviteRemplaceLesReglagesDunInvite() throws {
        let c = try charteAvecInvite(machines: [FabriqueCharte.serveur])
        var nouveaux = ReglagesInvite.parDefaut(machine: FabriqueCharte.serveur)
        nouveaux.simultanees = 5
        let suivante = try EditionCharte.changerInvite(
            c, auteur: FabriqueCharte.chef, membre: FabriqueCharte.invite, reglages: nouveaux, le: le)
        #expect(suivante.membre(FabriqueCharte.invite)?.invite?.simultanees == 5)
        #expect(
            refus {
                try EditionCharte.changerInvite(
                    c, auteur: FabriqueCharte.chef, membre: FabriqueCharte.serveur, reglages: nouveaux, le: le)
            } == "membre non invité")
    }

    @Test func champInconnuSurvitALEdition() throws {
        var membres = [
            FabriqueCharte.membre(FabriqueCharte.chef, .pair, cle()),
            FabriqueCharte.membre(FabriqueCharte.serveur, .serveur, cle()),
        ]
        guard case .objet(var pair) = FabriqueCharte.membre(FabriqueCharte.pair, .pair, cle(), droits: .aucun) else {
            Issue.record("membre de test mal formé")
            return
        }
        pair["couleur"] = .texte("bleu")
        membres.append(.objet(pair))
        guard
            case .objet(var brut) = FabriqueCharte.charte(
                version: 1, chefs: [FabriqueCharte.chef], par: FabriqueCharte.chef, membres: membres)
        else {
            Issue.record("charte de test mal formée")
            return
        }
        brut["futur"] = .nombre(7)
        let c = try CharteReseau(brut: .objet(brut))
        let suivante = try EditionCharte.nommerChef(
            c, auteur: FabriqueCharte.chef, membre: FabriqueCharte.pair, chef: true, le: le)
        #expect(suivante.brut["futur"] == .nombre(7))
        #expect(suivante.membresBrut.contains { $0["couleur"] == .texte("bleu") })
    }

    @Test func horodatageEstIso8601AvecMillisecondesEtZ() {
        #expect(EditionCharte.horodatage(Date(timeIntervalSince1970: 0)) == "1970-01-01T00:00:00.000Z")
    }
}
