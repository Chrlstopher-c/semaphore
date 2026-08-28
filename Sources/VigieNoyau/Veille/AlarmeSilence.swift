import Foundation

/// L'alarme de silence : trois notifications locales PRÉ-ARMÉES, annulées et
/// réarmées à chaque contact réussi avec le Pi.
///
/// `☠` C'est le dernier filet, et le seul qui survive à la mort du programme.
/// Tout le reste de la chaîne — session audio, réveils de fond, sondage en
/// premier plan — suppose que Vigie tourne encore. Si l'application est tuée par
/// le système, si la signature expire, si la session audio est perdue au premier
/// morceau joué, alors plus rien n'est relevé et l'écran reste muet. Sans cette
/// alarme, Chris lirait ce silence comme « rien ne s'est passé », alors qu'il
/// veut dire « je ne sais plus rien ». Une notification déjà déposée dans le
/// centre, elle, se déclenche même processus mort.
public enum AlarmeSilence {

    /// Trois échéances, choisies sur le rythme réel : une demi-journée de
    /// travail, une nuit, puis un jour entier. Espacées assez pour qu'un réveil
    /// tardif n'en fasse pas sonner deux d'affilée.
    public static let echeances: [TimeInterval] = [6 * 3600, 14 * 3600, 26 * 3600]

    /// `☠` iOS n'accepte que **64 requêtes en attente par application**, les
    /// plus anciennes étant écartées en silence au-delà. Trois alarmes de
    /// silence, une alarme de signature : le reste du budget doit rester libre
    /// pour les faits eux-mêmes.
    public static let budgetRequetes = 64

    public static func identifiant(_ rang: Int) -> String { "silence.\(rang)" }

    /// Les identifiants de toutes les alarmes, pour les annuler d'un bloc.
    public static var identifiants: [String] {
        echeances.indices.map(identifiant)
    }

    /// Les alarmes à poser pour un dernier contact donné. Une échéance déjà
    /// dépassée n'est PAS reposée à zéro : elle est simplement omise — poster
    /// « 6 h de silence » alors qu'il y en a eu 20 mentirait sur la durée.
    public static func projets(
        dernierContact: Date,
        maintenant: Date = Date()
    ) -> [ProjetNotification] {
        let ecoule = max(0, maintenant.timeIntervalSince(dernierContact))
        return echeances.indices.compactMap { rang in
            let reste = echeances[rang] - ecoule
            guard reste > 0 else { return nil }
            return projet(rang: rang, delai: reste)
        }
    }

    private static func projet(rang: Int, delai: TimeInterval) -> ProjetNotification {
        let heures = Int(echeances[rang] / 3600)
        return ProjetNotification(
            identifiant: identifiant(rang),
            genre: .silence,
            titre: "Vigie ne relève plus rien",
            sousTitre: "\(heures) h sans contact avec le Pi",
            corps: corps(rang: rang, heures: heures),
            fil: "silence",
            donnees: [ProjetNotification.Cle.genre: GenreAlerte.silence.rawValue],
            // Discrète à la première échéance : en pleine journée, six heures
            // sans contact arrivent pour de bonnes raisons. Les suivantes sonnent.
            insistance: rang == 0 ? .discrete : .active,
            delai: delai
        )
    }

    private static func corps(rang: Int, heures: Int) -> String {
        switch rang {
        case 0:
            return "Aucun relevé depuis \(heures) h. Ce silence n'est pas une "
                + "absence d'événement : ouvre Vigie pour savoir."
        case 1:
            return "Toujours rien depuis \(heures) h. L'application a "
                + "probablement été suspendue ou tuée — la chaîne d'alerte est "
                + "morte tant que Vigie n'est pas rouverte."
        default:
            return "\(heures) h sans le moindre contact. Vérifie la signature de "
                + "l'application et le tunnel du Pi : à ce stade, rien ne "
                + "remontera plus tout seul."
        }
    }
}
