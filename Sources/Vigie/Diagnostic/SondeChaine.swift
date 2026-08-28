// La sonde de chaîne : ce que le système accorde RÉELLEMENT à Vigie sur cet
// appareil, mesuré à l'instant plutôt que déduit de la documentation.
//
// `☠` Tout ce plan tient sur des mesures : le free provisioning refuse des
// capacités EN SILENCE (`.timeSensitive` se dégrade sans erreur), et une
// signature d'Impactor n'accorde pas les mêmes entitlements qu'une chaîne de
// compilation ordinaire. Cet écran est l'instrument qui a tranché
// l'architecture ; il reste embarqué pour rejouer la mesure le jour où
// quelque chose se met à mentir.
#if canImport(SwiftUI)
import Foundation
import UserNotifications
import VigieNoyau
#if canImport(UIKit)
import UIKit
#endif

/// Une ligne de relevé : ce qu'on a demandé, ce que l'appareil a répondu.
struct LigneSonde: Identifiable, Sendable {
    let id: String
    let intitule: String
    let verdict: String
    let ton: Ton

    init(_ intitule: String, _ verdict: String, _ ton: Ton = .neutre) {
        id = intitule
        self.intitule = intitule
        self.verdict = verdict
        self.ton = ton
    }
}

struct ReleveChaine: Sendable {
    var notifications: [LigneSonde] = []
    var stockage: [LigneSonde] = []
    var environnement: [LigneSonde] = []
}

enum SondeChaine {

    /// Compte dédié : la sonde ne touche JAMAIS le jeton de session, sous
    /// peine de déconnecter Chris en ouvrant un écran de diagnostic.
    private static let compteDEssai = "diagnostic.aller-retour"

    @MainActor
    static func relever(miroir: DepotMiroir) async -> ReleveChaine {
        var releve = ReleveChaine()
        releve.notifications = await sonderNotifications()
        releve.stockage = sonderStockage(miroir: miroir)
        releve.environnement = sonderEnvironnement()
        return releve
    }

    // MARK: - Notifications

    private static func sonderNotifications() async -> [LigneSonde] {
        let centre = UNUserNotificationCenter.current()
        let reglages = await centre.notificationSettings()
        let attente = await centre.pendingNotificationRequests().count
        let categories = await centre.notificationCategories().count
        return [
            LigneSonde("Autorisation", libelle(reglages.authorizationStatus), tonAutorisation(reglages)),
            LigneSonde("Bannières", libelle(reglages.alertSetting), ton(reglages.alertSetting)),
            LigneSonde("Son", libelle(reglages.soundSetting), ton(reglages.soundSetting)),
            LigneSonde("Écran verrouillé", libelle(reglages.lockScreenSetting), ton(reglages.lockScreenSetting)),
            // `☠` Les deux mesures qui ont commandé l'architecture : refusées
            // en free provisioning — aucune alerte ne perce un Concentration.
            LigneSonde("Temps réel", libelle(reglages.timeSensitiveSetting), ton(reglages.timeSensitiveSetting)),
            LigneSonde(
                "Alertes critiques",
                libelle(reglages.criticalAlertSetting),
                ton(reglages.criticalAlertSetting)
            ),
            LigneSonde("Requêtes en attente", "\(attente) / \(AlarmeSilence.budgetRequetes)", tonBudget(attente)),
            LigneSonde("Catégories posées", "\(categories)", categories > 0 ? .sain : .vigilance),
        ]
    }

    private static func tonAutorisation(_ reglages: UNNotificationSettings) -> Ton {
        switch reglages.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .sain
        case .notDetermined: return .vigilance
        default: return .danger
        }
    }

    /// Au-delà des trois quarts du budget iOS (64), les plus anciennes
    /// requêtes sont écartées EN SILENCE : l'alarme de silence disparaîtrait
    /// sans un mot.
    private static func tonBudget(_ attente: Int) -> Ton {
        attente >= (AlarmeSilence.budgetRequetes * 3) / 4 ? .danger : .sain
    }

    private static func libelle(_ statut: UNAuthorizationStatus) -> String {
        switch statut {
        case .authorized: return "accordée"
        case .provisional: return "provisoire"
        case .ephemeral: return "éphémère"
        case .denied: return "refusée"
        case .notDetermined: return "jamais demandée"
        @unknown default: return "inconnue"
        }
    }

    private static func libelle(_ reglage: UNNotificationSetting) -> String {
        switch reglage {
        case .enabled: return "accordé"
        case .disabled: return "coupé"
        case .notSupported: return "non supporté"
        @unknown default: return "inconnu"
        }
    }

    private static func ton(_ reglage: UNNotificationSetting) -> Ton {
        switch reglage {
        case .enabled: return .sain
        case .disabled: return .vigilance
        default: return .danger
        }
    }

    // MARK: - Stockage

    /// `☠` Le trousseau est la seule inconnue qui ne se voit qu'à l'exécution :
    /// les entitlements viennent d'Impactor, et `errSecMissingEntitlement`
    /// (-34018) ne se manifeste pas à la compilation. Un aller-retour réel
    /// vaut mieux qu'une hypothèse — la ressaisie hebdomadaire du mot de passe
    /// en dépend.
    private static func sonderStockage(miroir: DepotMiroir) -> [LigneSonde] {
        [essaiTrousseau(), etatMiroir(miroir.emplacement)]
    }

    private static func essaiTrousseau() -> LigneSonde {
        let voie = CoffreJeton(compte: compteDEssai).essai()
        switch voie {
        case .trousseau: return LigneSonde("Trousseau", voie.libelle, .sain)
        case .repliFichier: return LigneSonde("Trousseau", voie.libelle, .vigilance)
        case .echec: return LigneSonde("Trousseau", voie.libelle, .danger)
        }
    }

    private static func etatMiroir(_ fichier: URL) -> LigneSonde {
        let attributs = try? FileManager.default.attributesOfItem(atPath: fichier.path)
        guard let attributs, let octets = attributs[.size] as? Int else {
            return LigneSonde("Miroir", "aucun fichier — jamais écrit", .vigilance)
        }
        return LigneSonde("Miroir", "\(octets / 1024) Ko sur disque", .sain)
    }

    // MARK: - Environnement

    private static func sonderEnvironnement() -> [LigneSonde] {
        var lignes: [LigneSonde] = [
            LigneSonde("Bundle", Bundle.main.bundleIdentifier ?? "—"),
            LigneSonde("Modes de fond", modesDeFond()),
        ]
        #if canImport(UIKit)
        lignes.append(LigneSonde("Système", UIDevice.current.systemVersion))
        lignes.append(LigneSonde("Appareil", UIDevice.current.model))
        #endif
        return lignes
    }

    /// `UIBackgroundModes` est une clé d'Info.plist, PAS un entitlement : elle
    /// échappe à la signature Apple et fonctionne donc en free provisioning —
    /// c'est ce qui rend le maintien en vie audio possible du tout.
    private static func modesDeFond() -> String {
        let modes = Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String] ?? []
        return modes.isEmpty ? "aucun" : modes.joined(separator: ", ")
    }
}
#endif
