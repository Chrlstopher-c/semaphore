import Foundation

/// Mise en forme des grandeurs matérielles, en français.
///
/// Rédigée à la main plutôt que confiée à un `NumberFormatter` : celui-ci n'est
/// pas `Sendable`, suit la locale de l'appareil, et rendrait « 12.4 Go » sur un
/// téléphone réglé en anglais alors que tout le reste de l'écran est en
/// français. Ici, la virgule décimale est une décision, pas un effet de bord.
public enum FormatMachine {

    /// Ce qui s'affiche quand une grandeur n'a pas pu être mesurée.
    ///
    /// `☠` JAMAIS zéro : « pas mesuré » et « au repos » sont deux informations
    /// opposées, et c'est sur ces chiffres qu'on choisit où lancer une équipe.
    public static let absente = "—"

    // MARK: - Durées

    /// « 3 j 4 h », « 5 h 12 min », « 42 min ». Le tiret couvre l'uptime nul,
    /// qui n'existe pas sur une machine qui répond.
    public static func duree(_ secondes: Int) -> String {
        guard secondes > 0 else { return absente }
        let jours = secondes / 86_400
        let heures = (secondes % 86_400) / 3600
        let minutes = (secondes % 3600) / 60
        if jours > 0 { return "\(jours) j \(heures) h" }
        if heures > 0 { return "\(heures) h \(minutes) min" }
        return "\(minutes) min"
    }

    // MARK: - Grandeurs simples

    public static func pourcentage(_ valeur: Int?) -> String {
        guard let valeur else { return absente }
        return "\(valeur) %"
    }

    public static func temperature(_ celsius: Int?) -> String {
        guard let celsius else { return absente }
        return "\(celsius) °C"
    }

    // MARK: - Capacités

    /// « 12,4 / 31,3 Go ». Les mégaoctets du contrat deviennent des gigaoctets :
    /// personne ne lit « 32011 Mo » d'un coup d'œil.
    public static func memoire(utiliseeMo: Int?, totaleMo: Int?) -> String {
        guard let totaleMo, totaleMo > 0, let utiliseeMo else { return absente }
        return "\(decimale(Double(utiliseeMo) / 1024)) / \(decimale(Double(totaleMo) / 1024)) Go"
    }

    /// « 412 / 916 Go ». Sans décimale : un disque se lit en dizaines de Go.
    public static func disque(utiliseGo: Double?, totalGo: Double?) -> String {
        guard let totalGo, totalGo > 0, let utiliseGo else { return absente }
        return "\(Int(utiliseGo.rounded())) / \(Int(totalGo.rounded())) Go"
    }

    /// « 12,4 Mo » — la mémoire d'un GPU, servie en mégaoctets.
    public static func memoireGpu(utiliseeMo: Int?, totaleMo: Int?) -> String {
        guard let totaleMo, totaleMo > 0, let utiliseeMo else { return absente }
        return "\(utiliseeMo) / \(totaleMo) Mo"
    }

    // MARK: - Débits

    /// « 12,4 Ko/s » en dessous du mégaoctet, « 1,2 Mo/s » au-dessus. Un débit
    /// de sauvegarde afficherait sinon « 84213,7 Ko/s », illisible.
    public static func debit(_ kilooctetsParSeconde: Double) -> String {
        let ko = max(kilooctetsParSeconde, 0)
        if ko >= 1024 { return "\(decimale(ko / 1024)) Mo/s" }
        return "\(decimale(ko)) Ko/s"
    }

    // MARK: - Rouages

    /// Une décimale, virgule française.
    static func decimale(_ valeur: Double) -> String {
        String(format: "%.1f", valeur).replacingOccurrences(of: ".", with: ",")
    }
}
