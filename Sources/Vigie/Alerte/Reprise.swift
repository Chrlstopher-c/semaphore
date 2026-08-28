// Le filet : `BGAppRefreshTask`. Réveils opportunistes accordés par iOS quand
// la veille audio est tombée — une autre app a pris l'audio en exclusif, ou le
// système a fini par suspendre le processus.
//
// `☠` Environ la moitié des créneaux demandés ne sont jamais honorés, et aucun
// ne l'est après une mise à mort manuelle ou un redémarrage. Ce module ne
// promet donc rien : il rattrape. Ce qui compte est de distinguer un réveil
// RÉELLEMENT servi d'une intention de réveil — d'où `noterReveil`.
#if canImport(SwiftUI)
import BackgroundTasks
import Foundation
import VigieNoyau

enum Reprise {

    /// Doit correspondre à `BGTaskSchedulerPermittedIdentifiers` de l'Info.plist :
    /// un identifiant absent de la liste fait échouer l'enregistrement, et
    /// l'échec ne se voit qu'à l'exécution.
    static let identifiant = "com.echo.labs.refresh"

    /// Quinze minutes est un PLANCHER, jamais une promesse : iOS sert quand il
    /// veut, parfois une fois par jour.
    private static let delaiMinimalS: TimeInterval = 15 * 60

    /// `☠` À appeler dans `didFinishLaunching`, avant tout retour — iOS refuse
    /// tout enregistrement de tâche passé le lancement.
    @MainActor
    static func enregistrer() {
        let accepte = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifiant,
            using: nil
        ) { tache in
            guard let refresh = tache as? BGAppRefreshTask else { return tache.setTaskCompleted(success: false) }
            MainActor.assumeIsolated { executer(refresh) }
        }
        CentreAlerte.partage.noterReveil(enregistre: accepte, replanifie: false)
        if !accepte {
            Trace.erreur("alerte", "BGTaskScheduler a refusé l'enregistrement — aucun réveil de fond")
        }
        planifier()
    }

    /// `☠` Replanification OBLIGATOIRE à chaque exécution : une tâche servie ne
    /// se replanifie pas toute seule, et l'oublier donne une chaîne qui marche
    /// une fois puis se tait pour toujours.
    @MainActor
    private static func executer(_ tache: BGAppRefreshTask) {
        planifier()
        let travail = Task { @MainActor in
            await CentreAlerte.partage.sonder(origine: .reveilDeFond)
            tache.setTaskCompleted(success: true)
        }
        tache.expirationHandler = { travail.cancel() }
    }

    @MainActor
    static func planifier() {
        let demande = BGAppRefreshTaskRequest(identifier: identifiant)
        demande.earliestBeginDate = Date(timeIntervalSinceNow: delaiMinimalS)
        do {
            try BGTaskScheduler.shared.submit(demande)
            CentreAlerte.partage.noterReveil(enregistre: true, replanifie: true)
        } catch {
            // `BGTaskSchedulerErrorCodeUnavailable` en fait partie : l'app est
            // en arrière-plan restreint, ou les réveils de fond sont coupés dans
            // les réglages système. L'écran du canal doit le dire.
            Trace.erreur("alerte", "réveil de fond non planifié", error)
            CentreAlerte.partage.noterReveil(enregistre: true, replanifie: false)
        }
    }
}
#endif
