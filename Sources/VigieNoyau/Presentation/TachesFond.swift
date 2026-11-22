import Foundation

// Responsabilité : les tâches de fond d'une session telles que le panneau les montre — celles du SDK d'abord,
// celles du transcript (parité) à défaut. Port de `app/ui/src/parite/fusion.ts` (Lanterne). Pur.

/// Une tâche de fond, prête à afficher : même forme que le SDK et que la parité.
public struct TacheFond: Identifiable, Sendable, Equatable {
    public let id: String
    public let description: String
    public let genre: GenreTache
    /// Encore au travail : en cours ou en attente (compteur « N tâches en cours »).
    public let enCours: Bool
    /// Libellé français du statut (« En cours », « En pause »…).
    public let statut: String
    public let debutLe: String
    public let finLe: String?
    public let modele: String?
    /// Vient du transcript (parité), pas du SDK.
    public let deParite: Bool
    /// Peut être arrêtée depuis l'app : côté SDK, en cours ou en attente seulement.
    public let arretable: Bool
}

public enum TachesFond {
    /// Les tâches du SDK si elles existent, sinon celles du transcript ; plus récente d'abord.
    public static func fusion(sdk: [TacheSession], parite: PariteSession?) -> [TacheFond] {
        let taches: [TacheFond]
        if !sdk.isEmpty {
            taches = sdk.map(depuisSdk)
        } else if let parite, parite.transcript {
            taches = parite.taches.map(depuisParite)
        } else {
            taches = []
        }
        return taches.map { (tache: $0, debut: debut($0)) }.sorted { $0.debut > $1.debut }.map(\.tache)
    }

    /// Durée en secondes : jusqu'à la fin, ou jusqu'à `maintenant` pour une tâche encore au travail.
    /// 0 sans début lisible.
    public static func duree(_ tache: TacheFond, maintenant: Date) -> Int {
        guard let debut = DateRelative.date(tache.debutLe) else { return 0 }
        let fin = tache.finLe.flatMap(DateRelative.date) ?? maintenant
        return max(0, Int(fin.timeIntervalSince(debut)))
    }

    private static func depuisSdk(_ tache: TacheSession) -> TacheFond {
        let agent = tache.sousAgent != nil || tache.type.contains("agent")
        let vivante = tache.statut == "en_cours" || tache.statut == "en_attente"
        return TacheFond(
            id: tache.id, description: tache.description, genre: agent ? .agent : .commande,
            enCours: vivante, statut: libelleSdk(tache.statut), debutLe: tache.debutLe, finLe: tache.finLe,
            modele: tache.modele, deParite: false, arretable: vivante
        )
    }

    private static func depuisParite(_ tache: TacheParite) -> TacheFond {
        TacheFond(
            id: tache.id, description: tache.description, genre: tache.genre,
            enCours: tache.statut == .enCours, statut: libelleParite(tache.statut), debutLe: tache.debutLe,
            finLe: tache.finLe, modele: tache.modele, deParite: true, arretable: false
        )
    }

    /// Valeur brute du SDK → libellé. Un statut inconnu s'affiche tel quel.
    private static func libelleSdk(_ statut: String) -> String {
        switch statut {
        case "en_attente": return "En attente"
        case "en_cours": return "En cours"
        case "pausee": return "En pause"
        case "terminee": return "Terminée"
        case "echouee": return "Échouée"
        case "arretee": return "Arrêtée"
        default: return statut
        }
    }

    private static func libelleParite(_ statut: StatutTacheParite) -> String {
        switch statut {
        case .enCours: return "En cours"
        case .terminee: return "Terminée"
        case .echouee: return "Échouée"
        case .arretee: return "Arrêtée"
        }
    }

    /// Une date lue une fois par tâche : le tri ne relit pas l'ISO à chaque comparaison.
    private static func debut(_ tache: TacheFond) -> Date {
        DateRelative.date(tache.debutLe) ?? .distantPast
    }
}
