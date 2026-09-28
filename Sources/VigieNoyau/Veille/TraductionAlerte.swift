import Foundation

// Ce que la veille sonne : les notifications du relais d'un niveau « important » ou « alerte », jamais une deuxième
// fois. Le relais numérote ses notifications (`seq` croissant) : un filigrane suffit, sans liste d'identifiants.

public struct FiligraneRelais: Codable, Sendable, Equatable {
    public private(set) var dernierSeq: Int
    public private(set) var amorce: Bool

    public init() {
        dernierSeq = 0
        amorce = false
    }

    /// Premier relevé : on apprend le filigrane sans rien sonner — l'arriéré n'est pas une nouvelle.
    public mutating func retenir(_ lot: [NotificationRelais]) -> [NotificationRelais] {
        let nouvelles = lot.filter { $0.seq > dernierSeq }.sorted { $0.seq < $1.seq }
        dernierSeq = max(dernierSeq, lot.map(\.seq).max() ?? dernierSeq)
        defer { amorce = true }
        return amorce ? nouvelles.filter { $0.niveau != .info } : []
    }
}

public enum TraductionAlerte {
    public static func projet(pour n: NotificationRelais) -> ProjetNotification {
        let genre = genre(de: n)
        return ProjetNotification(
            identifiant: "relais.\(n.seq)",
            genre: genre,
            titre: n.titre,
            corps: n.texte,
            fil: n.sessionId.map { "session.\($0)" } ?? "parc",
            donnees: [ProjetNotification.Cle.genre: genre.rawValue, ProjetNotification.Cle.session: n.sessionId ?? ""],
            insistance: n.niveau == .info ? .discrete : .active,
            delai: nil
        )
    }

    static func genre(de n: NotificationRelais) -> GenreAlerte {
        if n.niveau == .alerte { return .erreur }
        if n.titre.hasSuffix("question") { return .question }
        if n.titre.hasSuffix("objectif atteint") { return .objectif }
        return .etape
    }
}
