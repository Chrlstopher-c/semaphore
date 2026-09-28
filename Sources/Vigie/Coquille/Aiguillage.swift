// Ce qu'on fait d'une notification touchée : ouvrir la session, ou y répondre directement depuis l'écran verrouillé.
#if canImport(SwiftUI)
import Foundation
import Observation
import VigieNoyau

@MainActor @Observable
final class Aiguillage: EcouteurNotifications {
    static let partage = Aiguillage()

    /// Session à ouvrir au prochain passage au premier plan (notification touchée).
    var sessionDemandee: String?
    /// Session à l'écran : ses notifications ne s'affichent pas en bannière, on la regarde déjà.
    var sessionVisible: String?
    @ObservationIgnored weak var modele: ModeleRelais?

    func presenter(_ fait: FaitNotifie) -> Bool {
        guard let session = fait.donnees[ProjetNotification.Cle.session], !session.isEmpty else { return true }
        return session != sessionVisible
    }

    func recevoir(_ fait: FaitNotifie) async {
        let session = fait.donnees[ProjetNotification.Cle.session] ?? ""
        guard !session.isEmpty else { return }
        if fait.action == CategoriesAlerte.Action.repondre, let texte = fait.saisie?.trimmingCharacters(in: .whitespacesAndNewlines),
           !texte.isEmpty {
            if let erreur = await modele?.envoyer(texte, a: session) {
                Trace.erreur("alerte", "réponse depuis la notification refusée : \(erreur)")
            }
            return
        }
        sessionDemandee = session
    }
}
#endif
