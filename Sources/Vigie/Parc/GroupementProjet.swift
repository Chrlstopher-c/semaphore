#if canImport(SwiftUI)
import Foundation
import VigieNoyau

/// Regroupe les équipes par PROJET, contrairement à `TriParc.groupes` qui
/// regroupe par état pour la file du quart. Deux axes, deux raisons de
/// changer : cet écran répond à « qu'est-ce qui tourne sur quoi », pas à
/// « qu'est-ce qui bloque » — d'où une fonction à part plutôt qu'un paramètre
/// ajouté à celle du quart.
enum GroupementProjet {

    static func groupes(_ missions: [MissionApi]) -> [GroupeParc] {
        let parProjet = Dictionary(grouping: missions, by: \.project)
        return parProjet.keys.sorted(by: comparer).map { projet in
            let triees = (parProjet[projet] ?? []).sorted(by: avant)
            return GroupeParc(id: projet, titre: projet, missions: triees)
        }
    }

    private static func comparer(_ gauche: String, _ droite: String) -> Bool {
        gauche.localizedCaseInsensitiveCompare(droite) == .orderedAscending
    }

    /// Dans un projet, l'état le plus urgent en tête, puis la plus récente.
    private static func avant(_ gauche: MissionApi, _ droite: MissionApi) -> Bool {
        let rangGauche = rang(gauche.state)
        let rangDroite = rang(droite.state)
        guard rangGauche == rangDroite else { return rangGauche < rangDroite }
        return gauche.epoch > droite.epoch
    }

    private static func rang(_ etat: EtatMissionApi) -> Int {
        switch etat {
        case .requiertAction: return 0
        case .enCours: return 1
        case .enPause: return 2
        case .auRepos: return 3
        case .echec: return 4
        case .terminee: return 5
        default: return 6
        }
    }
}
#endif
