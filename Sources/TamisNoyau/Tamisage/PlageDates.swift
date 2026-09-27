// Une période, bornée d'un côté, des deux, ou d'aucun.
import Foundation

public struct PlageDates: Sendable, Hashable, Codable {
    public var debut: Date?
    /// Borne haute EXCLUE : « jusqu'au 1er janvier » ne prend pas le 1er janvier.
    public var fin: Date?

    public init(debut: Date? = nil, fin: Date? = nil) {
        self.debut = debut
        self.fin = fin
    }

    public static let tout = PlageDates()

    /// Un cliché sans date n'entre que dans la plage illimitée : le ranger dans
    /// une période serait inventer sa date.
    public func contient(_ date: Date?) -> Bool {
        guard debut != nil || fin != nil else { return true }
        guard let date else { return false }
        if let debut, date < debut { return false }
        if let fin, date >= fin { return false }
        return true
    }

    /// Tout ce qui a plus de `annees` ans à la date `maintenant`.
    public static func plusDe(annees: Int, maintenant: Date = Date(), calendrier: Calendar = .current) -> PlageDates {
        PlageDates(fin: calendrier.date(byAdding: .year, value: -annees, to: maintenant))
    }

    /// L'année civile entière.
    public static func annee(_ annee: Int, calendrier: Calendar = .current) -> PlageDates {
        mois(annee: annee, mois: 1, duree: 12, calendrier: calendrier)
    }

    /// `duree` mois à partir de `mois` de `annee`.
    public static func mois(annee: Int, mois: Int, duree: Int = 1, calendrier: Calendar = .current) -> PlageDates {
        let debut = calendrier.date(from: DateComponents(year: annee, month: mois, day: 1))
        let fin = debut.flatMap { calendrier.date(byAdding: .month, value: duree, to: $0) }
        return PlageDates(debut: debut, fin: fin)
    }
}
