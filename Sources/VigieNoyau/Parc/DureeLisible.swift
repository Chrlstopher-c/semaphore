import Foundation

/// « Quand » et « combien de temps », pour le fil d'une équipe comme pour celui
/// d'un sous-agent.
///
/// `☠` Les durées se calculent sur `at` (millisecondes epoch), JAMAIS sur `ts`
/// (`HH:MM:SS`). Une soustraction d'heures murales donne −86 340 s au passage de
/// minuit — et une équipe lancée le soir travaille des deux côtés.
///
/// Rédigé à la main plutôt que par un `DateFormatter` : celui-ci n'est pas
/// `Sendable`, dépend de la locale de l'appareil, et rendrait un fil illisible
/// sur un téléphone configuré en anglais alors que tout le produit est français.
public enum DureeLisible {

    static let mois = [
        "janv.", "févr.", "mars", "avr.", "mai", "juin",
        "juil.", "août", "sept.", "oct.", "nov.", "déc.",
    ]

    /// Durée lisible. La précision suit l'ordre de grandeur : sous la minute, le
    /// dixième de seconde compte ; au-delà de l'heure, la seconde ne veut plus
    /// rien dire.
    public static func texte(millisecondes: Int) -> String {
        guard millisecondes >= 0 else { return "" }
        if millisecondes < 1000 { return "\(millisecondes) ms" }
        if millisecondes < 60_000 { return secondes(millisecondes) }
        let total = Int((Double(millisecondes) / 1000).rounded())
        let minutes = total / 60
        if minutes < 60 {
            let reste = total % 60
            return reste == 0 ? "\(minutes) min" : "\(minutes) min \(reste) s"
        }
        let heures = minutes / 60
        return "\(heures) h \(deuxChiffres(minutes % 60))"
    }

    private static func secondes(_ millisecondes: Int) -> String {
        let valeur = Double(millisecondes) / 1000
        guard valeur < 10 else { return "\(Int(valeur.rounded())) s" }
        let dixiemes = Int((valeur * 10).rounded())
        return "\(dixiemes / 10),\(dixiemes % 10) s"
    }

    /// L'heure telle qu'un fil doit l'écrire : `14:32` aujourd'hui, `7 août
    /// 14:32` sinon.
    ///
    /// `☠` Un fil laissé en autonomie franchit minuit. Sans le jour, deux heures
    /// murales s'ORDONNENT mais ne se DATENT pas : « 03:12 » posé au-dessus de
    /// « 23:47 » se lit comme un retour en arrière alors que c'est le lendemain —
    /// et c'est précisément le fil qu'on relit au réveil.
    public static func heureDeFil(
        epochMs: Int,
        maintenant: Date = Date(),
        calendrier: Calendar = .current
    ) -> String {
        let instant = Date(timeIntervalSince1970: Double(epochMs) / 1000)
        let champs = calendrier.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
        guard let heure = champs.hour, let minute = champs.minute else { return "" }
        let horloge = "\(deuxChiffres(heure)):\(deuxChiffres(minute))"
        guard !calendrier.isDate(instant, inSameDayAs: maintenant) else { return horloge }
        return "\(jour(champs, maintenant: maintenant, calendrier: calendrier)) \(horloge)"
    }

    /// L'heure seule, à la seconde — pour un fil dense où deux lignes partagent
    /// la minute.
    public static func heurePrecise(epochMs: Int, calendrier: Calendar = .current) -> String {
        let instant = Date(timeIntervalSince1970: Double(epochMs) / 1000)
        let champs = calendrier.dateComponents([.hour, .minute, .second], from: instant)
        guard let heure = champs.hour, let minute = champs.minute, let seconde = champs.second else {
            return ""
        }
        return "\(deuxChiffres(heure)):\(deuxChiffres(minute)):\(deuxChiffres(seconde))"
    }

    /// « 7 août », et l'année seulement si elle diffère : la porter partout
    /// allongerait chaque horodatage de la veille pour lever une ambiguïté qui
    /// n'existe qu'au-delà de douze mois.
    private static func jour(
        _ champs: DateComponents,
        maintenant: Date,
        calendrier: Calendar
    ) -> String {
        guard let numero = champs.day, let indexMois = champs.month, let annee = champs.year else {
            return ""
        }
        let nom = mois[max(0, min(indexMois - 1, mois.count - 1))]
        let anneeCourante = calendrier.component(.year, from: maintenant)
        return annee == anneeCourante ? "\(numero) \(nom)" : "\(numero) \(nom) \(annee)"
    }

    static func deuxChiffres(_ valeur: Int) -> String {
        valeur < 10 ? "0\(valeur)" : "\(valeur)"
    }
}
