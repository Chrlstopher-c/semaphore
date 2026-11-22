import Foundation

// Responsabilité : le catalogue des modèles, efforts et modes affichés par Quart (repris du menu modèle de Lanterne),
// et le nom lisible d'un identifiant de modèle (« claude-opus-5-5[1m] » → « Opus 5.5 »).

public struct ModeleCatalogue: Sendable, Equatable {
    public let id: String
    public let nom: String
    public let description: String
}

public enum CatalogueModeles {
    public static let principaux: [ModeleCatalogue] = [
        .init(id: "claude-opus-5-5", nom: "Opus 5.5", description: "Pour le travail complexe et le quotidien"),
        .init(id: "claude-fable-5-2", nom: "Fable 5.2", description: "Pour les défis les plus difficiles"),
        .init(id: "claude-sonnet-5-5", nom: "Sonnet 5.5", description: "Le plus efficace pour les tâches simples"),
        .init(id: "claude-haiku-5-5", nom: "Haiku 5.5", description: "Le plus rapide pour les réponses courtes"),
    ]

    public static let autres: [ModeleCatalogue] = [
        "claude-fable-5-1", "claude-haiku-4-5", "claude-sonnet-5", "claude-opus-5", "claude-fable-5",
        "claude-opus-4-8", "claude-opus-4-7", "claude-opus-4-6", "claude-sonnet-4-6", "claude-mythos-5-2",
        "claude-mythos-5-1",
    ].map { ModeleCatalogue(id: $0, nom: nom(id: $0), description: "") }

    /// Modes de permission (valeur du relais, libellé).
    public static let modesPermission: [(String, String)] = [
        ("default", "Demander"), ("acceptEdits", "Accepter les modifications"), ("plan", "Plan"),
        ("auto", "Auto"), ("bypassPermissions", "Tout autoriser"),
    ]

    /// « claude-opus-5-5 » → « Opus 5.5 » ; un alias court (« opus ») prend sa majuscule ; le reste passe tel quel.
    public static func nom(id: String) -> String {
        var brut = id.lowercased()
        if let crochet = brut.firstIndex(of: "[") { brut = String(brut[..<crochet]) }
        if brut.hasPrefix("claude-") { brut.removeFirst("claude-".count) }
        let morceaux = brut.split(separator: "-").map(String.init)
        guard let famille = morceaux.first, !famille.isEmpty else { return id }
        let version = morceaux.dropFirst().prefix { $0.allSatisfy(\.isNumber) && $0.count <= 2 }
        let titre = famille.prefix(1).uppercased() + famille.dropFirst()
        return version.isEmpty ? titre : "\(titre) \(version.joined(separator: "."))"
    }

    /// Le nom affiché d'une session : celui du SDK s'il l'a donné, sinon dérivé de l'identifiant.
    public static func nom(_ session: Session) -> String {
        if let n = session.modeleNom, !n.isEmpty { return n }
        return nom(id: session.modele)
    }

    public static func estCourant(_ m: ModeleCatalogue, _ session: Session?) -> Bool {
        guard let session else { return false }
        return nom(session).lowercased() == m.nom.lowercased()
    }

    public static func libelleEffort(_ effort: EffortSession?) -> String? {
        switch effort {
        case .low: return "Faible"
        case .medium: return "Moyen"
        case .high: return "Élevé"
        case .xhigh: return "Très élevé"
        case .max: return "Max"
        case nil: return nil
        }
    }
}
