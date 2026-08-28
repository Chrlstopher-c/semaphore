import Foundation

/// L'âge d'une donnée, en français lisible.
///
/// `☠` La règle du produit : **jamais un indicateur d'attente quand une donnée
/// ancienne existe**. Un tourniquet dit « je ne sais pas » ; « relevé il y a
/// 3 h » dit ce qu'on sait et depuis quand. Le second se décide, le premier non.
public enum Fraicheur {

    /// Ce que vaut une donnée de cet âge. Les seuils sont ceux de la charte
    /// (`IndicateurFraicheur`) : deux minutes, puis une heure.
    public enum Degre: Sendable, Equatable {
        case fraiche
        case vieillissante
        case perimee
    }

    public static let seuilFraiche: TimeInterval = 120
    public static let seuilVieillissante: TimeInterval = 3600

    public static func age(depuis releve: Date, maintenant: Date = Date()) -> TimeInterval {
        max(0, maintenant.timeIntervalSince(releve))
    }

    public static func degre(depuis releve: Date, maintenant: Date = Date()) -> Degre {
        let ecart = age(depuis: releve, maintenant: maintenant)
        if ecart < seuilFraiche { return .fraiche }
        if ecart < seuilVieillissante { return .vieillissante }
        return .perimee
    }

    /// « à l'instant », « il y a 12 min », « il y a 3 h », « hier », « il y a 4 j ».
    ///
    /// Rédigé à la main plutôt que par `RelativeDateTimeFormatter` : celui-ci
    /// n'est pas `Sendable`, dépend de la locale de l'appareil, et rend « il y a
    /// 1 heure » pour 61 minutes comme pour 119 — l'écart entre les deux compte
    /// quand on décide de relancer une machine.
    public static func texte(depuis releve: Date, maintenant: Date = Date()) -> String {
        let secondes = Int(age(depuis: releve, maintenant: maintenant))
        if secondes < 10 { return "à l'instant" }
        if secondes < 60 { return "il y a \(secondes) s" }
        if secondes < 3600 { return "il y a \(secondes / 60) min" }
        if secondes < 86_400 { return "il y a \(secondes / 3600) h" }
        if secondes < 172_800 { return "hier" }
        return "il y a \(secondes / 86_400) j"
    }

    /// Forme complète : « relevé il y a 3 h ». Le verbe importe — il dit que la
    /// donnée a été VUE à ce moment-là, pas qu'elle a changé.
    public static func mention(depuis releve: Date, maintenant: Date = Date()) -> String {
        "relevé \(texte(depuis: releve, maintenant: maintenant))"
    }
}
