// La seule traduction `ProjetNotification` → `UNNotificationRequest` du
// programme. Aucune règle de contenu ici : elles vivent dans `VigieNoyau`, où
// elles s'éprouvent sans iPhone.
#if canImport(SwiftUI)
import Foundation
import UserNotifications
import VigieNoyau

enum Sonneur {

    /// Pose une alerte. `nil` en retour = posée ; sinon la description du refus,
    /// que l'écran du canal affiche tel quel.
    @discardableResult
    static func poser(_ projet: ProjetNotification) async -> String? {
        let requete = UNNotificationRequest(
            identifier: projet.identifiant,
            content: contenu(projet),
            trigger: declencheur(projet)
        )
        do {
            try await UNUserNotificationCenter.current().add(requete)
            return nil
        } catch {
            Trace.erreur("alerte", "pose refusée pour \(projet.identifiant)", error)
            return error.localizedDescription
        }
    }

    static func retirer(_ identifiants: [String]) {
        guard !identifiants.isEmpty else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiants)
    }

    private static func contenu(_ projet: ProjetNotification) -> UNMutableNotificationContent {
        let contenu = UNMutableNotificationContent()
        contenu.title = projet.titre
        if let sousTitre = projet.sousTitre { contenu.subtitle = sousTitre }
        contenu.body = projet.corps
        contenu.categoryIdentifier = projet.genre.categorie
        if let fil = projet.fil { contenu.threadIdentifier = fil }
        contenu.userInfo = projet.donnees
        // `☠` Le niveau s'arrête à `.active` : `.timeSensitive` est refusé en
        // free provisioning et se dégrade EN SILENCE. Le demander donnerait
        // l'illusion d'une alerte qui perce un mode Concentration.
        contenu.interruptionLevel = projet.insistance == .discrete ? .passive : .active
        contenu.sound = projet.insistance == .discrete ? nil : .default
        return contenu
    }

    /// `☠` Un déclencheur d'intervalle nul est REFUSÉ par iOS. Une alerte
    /// immédiate se pose sans déclencheur du tout, ce qui la présente aussitôt.
    private static func declencheur(_ projet: ProjetNotification) -> UNNotificationTrigger? {
        guard let delai = projet.delai, delai > 0 else { return nil }
        return UNTimeIntervalNotificationTrigger(timeInterval: delai, repeats: false)
    }
}
#endif
