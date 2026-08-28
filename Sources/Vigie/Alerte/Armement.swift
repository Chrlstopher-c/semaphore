// Les alertes PRÉ-ARMÉES : celles qui se déclenchent même processus mort.
//
// `☠` C'est la seule partie de la chaîne qui survive à la mort de Vigie. Tout
// le reste — veille audio, réveils de fond, sondage en premier plan — suppose
// que l'application tourne encore. Une chaîne d'alerte doit dénoncer sa propre
// mort, faute de quoi le silence se lit comme « rien ne s'est passé ».
#if canImport(SwiftUI)
import Foundation
import UserNotifications
import VigieNoyau

enum Armement {

    /// Réarme les trois alarmes de silence à partir du dernier contact réussi.
    /// Annulation puis pose : sans le retrait préalable, iOS empile des requêtes
    /// de même identifiant jusqu'au plafond de 64, et écarte les plus anciennes
    /// en silence — c'est-à-dire précisément celles qui devaient sonner.
    @discardableResult
    static func armerAlarmeDeSilence(dernierContact: Date) async -> [Date] {
        Sonneur.retirer(AlarmeSilence.identifiants)
        let projets = AlarmeSilence.projets(dernierContact: dernierContact)
        for projet in projets { await Sonneur.poser(projet) }
        return projets.compactMap { projet in
            projet.delai.map { Date().addingTimeInterval($0) }
        }
    }

    /// L'avertissement de signature, posé la veille de l'expiration.
    ///
    /// > Non vérifié sur cette chaîne : une locale déjà programmée se
    /// > déclenche-t-elle encore quand le profil a expiré et que l'application
    /// > n'est plus lançable ? Toute la valeur de cette alerte en dépend.
    @discardableResult
    static func armerExpirationSignature() async -> Date? {
        guard let expiration = lireExpiration() else { return nil }
        Sonneur.retirer(["signature.expiration"])
        guard let projet = ExpirationSignature.projet(expiration: expiration) else {
            return expiration
        }
        await Sonneur.poser(projet)
        return expiration
    }

    /// `☠` Chemin résolu à CHAQUE lecture : l'UUID du conteneur change à chaque
    /// pose d'un IPA resigné, alors même que les données survivent. Un chemin
    /// absolu mémorisé pointerait dans le vide.
    static func lireExpiration() -> Date? {
        guard let url = Bundle.main.url(
            forResource: ExpirationSignature.nomFichier,
            withExtension: ExpirationSignature.extensionFichier
        ) else {
            Trace.info("alerte", "profil de provisionnement absent — échéance inconnue")
            return nil
        }
        do {
            return ExpirationSignature.lire(try Data(contentsOf: url))
        } catch {
            Trace.erreur("alerte", "profil de provisionnement illisible", error)
            return nil
        }
    }
}
#endif
