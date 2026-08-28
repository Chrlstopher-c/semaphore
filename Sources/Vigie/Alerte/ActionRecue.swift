// Ce qui se passe quand Chris tranche depuis l'écran verrouillé, sans ouvrir
// l'application.
//
// `☠` C'est le geste le plus engageant du produit : approuver un mandat
// dispatche une équipe réelle qui dépense de l'argent. Le bouton exige donc
// Face ID (`authenticationRequired`, posé par `CategoriesAlerte`), et le
// résultat — succès comme refus métier — REVIENT par une notification : sans
// retour, on ne sait pas si l'équipe est partie, et on approuve deux fois.
#if canImport(SwiftUI)
import Foundation
import Observation
import VigieNoyau

/// Une ouverture demandée par une notification, lue par la coquille.
public struct OuvertureDemandee: Equatable, Sendable {
    public let domaine: Domaine
    public let fil: String?
}

@MainActor
@Observable
public final class ActionRecue: EcouteurNotifications {
    public static let partage = ActionRecue()

    /// Consommée par la coquille, puis remise à `nil`.
    public var ouverture: OuvertureDemandee?

    @ObservationIgnored private var client: ClientPi?

    private init() {}

    public func brancher(client: ClientPi) {
        self.client = client
    }

    /// Vigie est à l'écran : la bannière ferait doublon avec la file, SAUF pour
    /// ce qui engage une décision — un mandat qui arrive pendant qu'on lit un
    /// fil doit se voir sans changer d'onglet.
    public func presenter(_ fait: FaitNotifie) -> Bool {
        switch genre(fait) {
        // Ce qui engage une décision se voit sans changer d'onglet.
        case .mandat, .echec, .arbitrage: return true
        // `☠` Une réponse de fil, NON : si Vigie est à l'écran, ou bien le fil
        // est ouvert et la réponse s'y affiche déjà, ou bien elle attend dans la
        // liste. Une bannière par-dessus doublonnerait avec ce qu'on regarde.
        default: return false
        }
    }

    public func recevoir(_ fait: FaitNotifie) async {
        switch fait.action {
        case CategoriesAlerte.Action.approuverMandat:
            await trancher(fait, chemin: Route.approuverMandat, cle: ProjetNotification.Cle.proposition,
                           verbe: "autorisé")
        case CategoriesAlerte.Action.refuserMandat:
            await trancher(fait, chemin: Route.refuserMandat, cle: ProjetNotification.Cle.proposition,
                           verbe: "refusé")
        case CategoriesAlerte.Action.accorderRallonge:
            await trancher(fait, chemin: Route.accorderRallonge, cle: ProjetNotification.Cle.rallonge,
                           verbe: "accordée")
        case CategoriesAlerte.Action.refuserRallonge:
            await trancher(fait, chemin: Route.refuserRallonge, cle: ProjetNotification.Cle.rallonge,
                           verbe: "refusée")
        default:
            ouverture = OuvertureDemandee(
                domaine: domaineDe(fait),
                fil: fait.donnees[ProjetNotification.Cle.fil]
            )
        }
    }

    // MARK: - Écriture

    private func trancher(
        _ fait: FaitNotifie,
        chemin: (String) -> String,
        cle: String,
        verbe: String
    ) async {
        guard let client, let identifiant = fait.donnees[cle] else {
            await rendreCompte(titre: "Geste perdu", corps: "L'identifiant manquait dans la notification.")
            return
        }
        switch await client.ecrire(chemin(identifiant)) {
        case .success:
            await rendreCompte(titre: "C'est \(verbe)", corps: "Le Pi a accepté le geste.")
            // Le fait tranché ne doit plus attendre dans le centre.
            Sonneur.retirer([fait.identifiant])
            await CentreAlerte.partage.sonder(origine: .ouverture)
        case .failure(let erreur):
            await rendreCompte(titre: "Refusé par le serveur", corps: erreur.message)
        }
    }

    /// Le retour passe par une notification et non par un écran : le geste a été
    /// fait téléphone verrouillé, il n'y a aucun écran pour l'accueillir.
    private func rendreCompte(titre: String, corps: String) async {
        await Sonneur.poser(
            ProjetNotification(
                identifiant: "retour.\(Int(Date().timeIntervalSince1970))",
                genre: .parc,
                titre: titre,
                corps: corps,
                fil: "retour",
                insistance: .discrete
            )
        )
    }

    // MARK: - Lecture du fait

    private func genre(_ fait: FaitNotifie) -> GenreAlerte? {
        fait.donnees[ProjetNotification.Cle.genre].flatMap(GenreAlerte.init(rawValue:))
    }

    private func domaineDe(_ fait: FaitNotifie) -> Domaine {
        switch genre(fait) {
        case .mandat, .rallonge, .arbitrage: return .decisions
        case .reponse: return .fil
        case .equipe, .echec: return .parc
        case .silence, .signature: return .alerte
        default: return fait.donnees[ProjetNotification.Cle.fil] == nil ? .quart : .fil
        }
    }
}
#endif
