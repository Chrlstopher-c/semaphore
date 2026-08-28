import Foundation

/// Ce qu'un relevé matériel dit de l'état d'une machine — pas ce qu'il vaut en
/// chiffres. C'est cette grandeur, et elle seule, qui décide de la couleur.
public enum DegreSanteMachine: String, Sendable, Equatable {
    /// Ne répond plus au Pi. `☠` Ce n'est PAS une panne : le poste de travail
    /// éteint la nuit est le régime nominal, et ses missions repartiront à son
    /// retour (H-75). D'où un état neutre, là où la webapp peint du rouge.
    case horsLigne
    /// Rattachée, mais aucun chiffre : le lien répond, la mesure non.
    case sansReleve
    case sain
    case vigilance
    case danger
}

/// Seuils de bascule, en un seul endroit pour qu'ils se discutent.
///
/// `☠` La charge PROCESSEUR n'en fait volontairement pas partie. Une machine à
/// 100 % de CPU est une machine qui travaille : c'est le régime attendu quand
/// trois équipes tournent. Peindre ça en rouge apprendrait à ignorer le rouge.
/// Ce qui menace réellement le parc, c'est un disque qui se remplit, une
/// mémoire qui sature et un processeur qui se bride en chauffant.
public enum SeuilsMachine {
    public static let disqueVigilancePct = 80
    public static let disqueDangerPct = 90
    public static let memoireVigilancePct = 85
    public static let memoireDangerPct = 95
    /// Au-delà, un processeur de portable se bride ; au-delà du second, il se
    /// bride franchement et les équipes ralentissent sans rien signaler.
    public static let temperatureVigilanceC = 75
    public static let temperatureDangerC = 85
}

public enum SanteMachine {

    public static func degre(enLigne: Bool, metriques: MetriquesHote?) -> DegreSanteMachine {
        guard enLigne else { return .horsLigne }
        guard let metriques else { return .sansReleve }
        if aFranchi(metriques, danger: true) { return .danger }
        if aFranchi(metriques, danger: false) { return .vigilance }
        return .sain
    }

    /// Ce qui a déclenché la bascule, en clair. `nil` sur une machine saine :
    /// une carte verte n'a rien à expliquer.
    public static func motif(enLigne: Bool, metriques: MetriquesHote?) -> String? {
        guard enLigne else { return nil }
        guard let metriques else {
            return "Machine rattachée, relevé indisponible — le lien répond, la mesure non."
        }
        var motifs: [String] = []
        if let part = partDisquePct(metriques), part >= SeuilsMachine.disqueVigilancePct {
            motifs.append("disque à \(part) %")
        }
        if let memoire = metriques.memPct, memoire >= SeuilsMachine.memoireVigilancePct {
            motifs.append("mémoire à \(memoire) %")
        }
        if let temperature = metriques.tempCpuC, temperature >= SeuilsMachine.temperatureVigilanceC {
            motifs.append("processeur à \(temperature) °C")
        }
        return motifs.isEmpty ? nil : motifs.joined(separator: " · ")
    }

    private static func aFranchi(_ metriques: MetriquesHote, danger: Bool) -> Bool {
        let disque = danger ? SeuilsMachine.disqueDangerPct : SeuilsMachine.disqueVigilancePct
        let memoire = danger ? SeuilsMachine.memoireDangerPct : SeuilsMachine.memoireVigilancePct
        let chaleur = danger ? SeuilsMachine.temperatureDangerC : SeuilsMachine.temperatureVigilanceC
        if let part = partDisquePct(metriques), part >= disque { return true }
        if let occupee = metriques.memPct, occupee >= memoire { return true }
        if let temperature = metriques.tempCpuC, temperature >= chaleur { return true }
        return false
    }

    static func partDisquePct(_ metriques: MetriquesHote) -> Int? {
        guard let part = metriques.partDisque else { return nil }
        return Int((part * 100).rounded())
    }
}
