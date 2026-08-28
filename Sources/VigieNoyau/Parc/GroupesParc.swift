import Foundation

/// Le filtre du parc, tel qu'il s'affiche en tête de liste.
public enum FiltreParc: String, Sendable, CaseIterable, Identifiable, Hashable {
    case tout
    case arbitrage
    case enCours
    case repos
    case arretees

    public var id: String { rawValue }

    public var titre: String {
        switch self {
        case .tout: return "Tout"
        case .arbitrage: return "Arbitrage"
        case .enCours: return "En cours"
        case .repos: return "Au repos"
        case .arretees: return "Arrêtées"
        }
    }

    public func retient(_ mission: MissionApi) -> Bool {
        switch self {
        case .tout: return true
        case .arbitrage: return mission.state == .requiertAction
        case .enCours: return mission.state == .enCours
        case .repos: return mission.state == .auRepos || mission.state == .enPause
        case .arretees: return mission.state == .echec || mission.state == .terminee
        }
    }
}

/// Une section de la liste du parc.
public struct GroupeParc: Sendable, Identifiable, Hashable {
    public let id: String
    public let titre: String
    public let missions: [MissionApi]

    public init(id: String, titre: String, missions: [MissionApi]) {
        self.id = id
        self.titre = titre
        self.missions = missions
    }
}

/// Un compteur de la rangée de tête.
public struct CompteurParc: Sendable, Identifiable, Hashable {
    public let id: String
    public let etiquette: String
    public let valeur: Int
    /// Ce compteur réclame-t-il l'œil ? Un seul le fait, et seulement s'il n'est
    /// pas à zéro — sinon l'accent cesse d'être un signal.
    public let alerte: Bool
}

public enum TriParc {

    /// Les groupes affichés, dans l'ordre où on veut les lire : ce qui attend
    /// une décision d'abord, ce qui est mort en dernier.
    ///
    /// `☠` Un état INCONNU tombe dans « Autres états » plutôt que d'être filtré.
    /// `EtatMissionApi` est une liste ouverte : un état ajouté côté Pi ferait
    /// disparaître des équipes de l'écran sans qu'aucune erreur ne le dise.
    public static func groupes(_ missions: [MissionApi]) -> [GroupeParc] {
        let plans: [(String, String, Set<EtatMissionApi>)] = [
            ("arbitrage", "Demande ton arbitrage", [.requiertAction]),
            ("encours", "En cours", [.enCours]),
            ("repos", "Au repos", [.auRepos]),
            ("pause", "En pause", [.enPause]),
            ("arretees", "Arrêtées", [.echec, .terminee]),
        ]
        var groupes = plans.compactMap { identifiant, titre, etats -> GroupeParc? in
            let retenues = missions.filter { etats.contains($0.state) }
            guard !retenues.isEmpty else { return nil }
            return GroupeParc(id: identifiant, titre: titre, missions: retenues)
        }
        let connus = Set(plans.flatMap(\.2))
        let inconnues = missions.filter { !connus.contains($0.state) }
        if !inconnues.isEmpty {
            groupes.append(GroupeParc(id: "autres", titre: "Autres états", missions: inconnues))
        }
        return groupes
    }

    public static func compteurs(_ missions: [MissionApi]) -> [CompteurParc] {
        let arbitrage = compter(missions, .requiertAction)
        return [
            CompteurParc(id: "arbitrage", etiquette: "Arbitrage", valeur: arbitrage, alerte: arbitrage > 0),
            CompteurParc(id: "encours", etiquette: "En cours", valeur: compter(missions, .enCours), alerte: false),
            CompteurParc(id: "repos", etiquette: "Au repos", valeur: compter(missions, .auRepos), alerte: false),
            CompteurParc(id: "pause", etiquette: "En pause", valeur: compter(missions, .enPause), alerte: false),
            CompteurParc(id: "echec", etiquette: "Échec", valeur: compter(missions, .echec), alerte: false),
            CompteurParc(id: "terminee", etiquette: "Terminées", valeur: compter(missions, .terminee), alerte: false),
        ]
    }

    static func compter(_ missions: [MissionApi], _ etat: EtatMissionApi) -> Int {
        missions.reduce(0) { total, mission in mission.state == etat ? total + 1 : total }
    }

    /// La ligne de sous-titre du parc : ce que la liste contient réellement.
    public static func resume(_ missions: [MissionApi]) -> String {
        let projets = Set(missions.map(\.project)).count
        let equipes = missions.filter { $0.state.estVivante }.count
        return "\(missions.count) équipes · \(projets) projets · \(equipes) vivantes"
    }
}
