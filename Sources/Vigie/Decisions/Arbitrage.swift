// L'exécution d'un geste de décision : garde biométrique, écriture, et lecture
// du refus quand il y en a un.
//
// `☠` Le geste n'est PAS optimiste. Une carte ne disparaît que lorsque le
// serveur a confirmé — mesuré en production le 01/08 : une carte périmée
// cliquée 16 s trop tard rendait un 409, et l'interface optimiste avait déjà
// annoncé le contraire.
#if canImport(SwiftUI)
import Foundation
import Observation
import VigieNoyau

@MainActor
@Observable
final class Arbitrage {
    /// Le geste en cours, s'il y en a un : les boutons de CETTE carte seulement
    /// se désarment, jamais toute la file.
    private(set) var enCours: String?
    /// Les conduites à afficher, par `Decision.id`.
    private(set) var conduites: [String: ConduiteApresConflit] = [:]
    /// Les décisions confirmées tranchées, à retirer de la file.
    private(set) var tranchees: Set<String> = []

    private let client: ClientPi

    init(client: ClientPi) {
        self.client = client
    }

    func conduite(pour decision: Decision) -> ConduiteApresConflit? {
        conduites[decision.id]
    }

    func estTranchee(_ decision: Decision) -> Bool {
        tranchees.contains(decision.id)
    }

    func oublier(_ decision: Decision) {
        conduites[decision.id] = nil
    }

    // MARK: - Gestes

    func approuver(_ decision: Decision) async {
        await executer(
            decision,
            chemin: cheminAccord(decision),
            corps: corpsAccord(decision),
            motif: motifDeGarde(decision)
        )
    }

    func refuser(_ decision: Decision) async {
        await executer(
            decision,
            chemin: cheminRefus(decision),
            corps: corpsRefus(decision),
            motif: "Refuser : \(decision.intitule)"
        )
    }

    private func executer(
        _ decision: Decision,
        chemin: String,
        corps: CorpsJSON?,
        motif: String
    ) async {
        guard enCours == nil else { return }
        enCours = decision.id
        defer { enCours = nil }
        conduites[decision.id] = nil

        if case .refusee(let raison) = await GardeFaceID.exiger(motif) {
            conduites[decision.id] = .gardeRefusee(raison, decision)
            return
        }
        switch await client.ecrire(chemin, corps) {
        case .success:
            tranchees.insert(decision.id)
        case .failure(let erreur):
            let conduite = ConduiteApresConflit.pour(erreur, decision)
            conduites[decision.id] = conduite
            if conduite.quitteLaFile { tranchees.insert(decision.id) }
        }
    }

    // MARK: - Routes

    /// `☠` Trois circuits séparés côté serveur, trois routes distinctes. Un
    /// arbitrage d'inspection n'est pas un mandat : il tranche une équipe déjà
    /// partie, qui tourne et dépense pendant qu'on hésite.
    private func cheminAccord(_ decision: Decision) -> String {
        switch decision {
        case .mandat(let proposition): return Route.approuverMandat(proposition.id)
        case .rallonge(let demande): return Route.accorderRallonge(demande.id)
        case .arbitrage(let mission): return Route.arbitrerInspection(mission.id)
        }
    }

    private func cheminRefus(_ decision: Decision) -> String {
        switch decision {
        case .mandat(let proposition): return Route.refuserMandat(proposition.id)
        case .rallonge(let demande): return Route.refuserRallonge(demande.id)
        case .arbitrage(let mission): return Route.arbitrerInspection(mission.id)
        }
    }

    /// `☠` Un arbitrage d'inspection n'a pas deux routes mais deux CORPS.
    /// `decline` = « j'ai vu et je poursuis en connaissance de cause » — ce qui
    /// n'est pas « je n'ai jamais regardé ». `confirme` valide le verdict de
    /// boucle, et l'équipe s'arrête.
    private func corpsAccord(_ decision: Decision) -> CorpsJSON? {
        guard case .arbitrage = decision else { return nil }
        return ["decision": "decline"]
    }

    private func corpsRefus(_ decision: Decision) -> CorpsJSON? {
        guard case .arbitrage = decision else { return nil }
        return ["decision": "confirme"]
    }

    private func motifDeGarde(_ decision: Decision) -> String {
        switch decision {
        case .mandat(let proposition):
            let droit = proposition.acces.ouvreLEcriture ? "écriture" : "lecture seule"
            return "Autoriser \(proposition.projet) · \(droit)"
        case .rallonge:
            return "Accorder : \(decision.intitule)"
        case .arbitrage:
            return "Laisser poursuivre : \(decision.intitule)"
        }
    }
}
#endif
