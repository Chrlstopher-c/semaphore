import Foundation

// Responsabilité : une date ISO dite en français, relative à maintenant (« 5 min », « hier », « 10 nov. »).

public enum DateRelative {
    private static let mois = [
        "janv.", "févr.", "mars", "avr.", "mai", "juin",
        "juil.", "août", "sept.", "oct.", "nov.", "déc.",
    ]

    /// Une date ISO8601, avec ou sans fractions de seconde. Une date illisible donne une chaîne vide.
    public static func texte(iso: String, maintenant: Date, fuseau: TimeZone = .current) -> String {
        guard let date = date(iso) else { return "" }
        return texte(date: date, maintenant: maintenant, fuseau: fuseau)
    }

    public static func texte(date: Date, maintenant: Date, fuseau: TimeZone = .current) -> String {
        let ecart = maintenant.timeIntervalSince(date)
        if ecart < 60 { return "maintenant" }
        if ecart < 3600 { return "\(Int(ecart / 60)) min" }
        if ecart < 86_400 { return "\(Int(ecart / 3600)) h" }
        return calendaire(date, maintenant: maintenant, fuseau: fuseau)
    }

    /// `☠` Construire un `ISO8601DateFormatter` coûte cher (~0,1 ms sur A12) : la liste en créait deux par session à
    /// chaque rendu, donc à chaque message du flux. Formateurs partagés, sous verrou : la Foundation de Linux ne les
    /// garantit pas sûrs entre fils d'exécution (plantage relevé en tests parallèles).
    nonisolated(unsafe) private static let avecFractions: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let simple: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let verrou = NSLock()

    public static func date(_ iso: String) -> Date? {
        verrou.lock()
        defer { verrou.unlock() }
        return avecFractions.date(from: iso) ?? simple.date(from: iso)
    }

    private static func calendaire(_ date: Date, maintenant: Date, fuseau: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = fuseau
        let jour = cal.dateComponents([.year, .month, .day], from: date)
        let hier = cal.date(byAdding: .day, value: -1, to: maintenant) ?? maintenant
        let veille = cal.dateComponents([.year, .month, .day], from: hier)
        if jour.year == veille.year && jour.month == veille.month && jour.day == veille.day { return "hier" }
        let aujourdhui = cal.dateComponents([.year], from: maintenant)
        let nomMois = mois[(jour.month ?? 1) - 1]
        let court = "\(jour.day ?? 1) \(nomMois)"
        return jour.year == aujourdhui.year ? court : "\(court) \(jour.year ?? 0)"
    }
}
