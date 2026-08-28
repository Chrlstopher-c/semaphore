import Foundation

/// Ce que chaque machine PORTE réellement.
///
/// Une charge processeur seule ne dit pas si le processeur travaille pour le
/// harness ou pour autre chose — et c'est exactement la question qu'on se pose
/// devant cet écran. Croiser la liste des machines avec les équipes vivantes est
/// la seule façon d'y répondre.
public enum ChargeMachines {

    /// Équipes vivantes par identifiant de machine.
    ///
    /// `☠` Les états terminaux sont exclus par `EtatMissionApi.estVivante`, jamais
    /// par une liste recopiée ici : le front en tenait une copie (`pcview.js`), et
    /// deux listes d'états finissent toujours par diverger d'un cas.
    public static func equipesParMachine(_ missions: [MissionApi]) -> [String: [MissionApi]] {
        var parMachine: [String: [MissionApi]] = [:]
        for mission in missions where mission.state.estVivante {
            // `nil` ⇒ mission antérieure au multi-machines : elle n'est rattachable
            // à aucune carte, et l'attribuer au hasard mentirait sur deux cartes.
            guard let machine = mission.machine else { continue }
            parMachine[machine, default: []].append(mission)
        }
        return parMachine
    }

    /// Équipes vivantes rattachées à un compte Claude, pour la carte de quota.
    public static func equipesParCompte(_ missions: [MissionApi]) -> [String: [MissionApi]] {
        var parCompte: [String: [MissionApi]] = [:]
        for mission in missions where mission.state.estVivante {
            parCompte[mission.account, default: []].append(mission)
        }
        return parCompte
    }

    /// « 2 machines sur 3 en ligne ». Le dénominateur compte : une machine
    /// éteinte reste au parc, elle n'a pas disparu.
    public static func mention(machines: [MachineApi]) -> String {
        guard !machines.isEmpty else { return "aucune machine rattachée" }
        let enLigne = machines.filter(\.enLigne).count
        let accord = machines.count > 1 ? "s" : ""
        return "\(enLigne)/\(machines.count) machine\(accord) en ligne"
    }
}
