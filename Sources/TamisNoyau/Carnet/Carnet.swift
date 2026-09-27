// Ce qui survit d'un lancement à l'autre : les décisions de Chris et ce que
// l'analyse a appris. Deux fichiers séparés, parce qu'ils n'ont pas la même
// valeur — perdre le carnet coûte une demi-heure d'analyse, perdre les
// décisions coûte des heures de tri.
import Foundation

public struct Decisions: Codable, Sendable, Hashable {
    /// Ce qui partira à la prochaine suppression.
    public var panier: Set<String> = []
    /// Ce qu'on a vu et décidé de garder : ni le tri ni les pistes ne le
    /// reproposent.
    public var gardes: Set<String> = []

    public init() {}

    public mutating func mettreAuPanier(_ ids: some Sequence<String>) {
        for id in ids {
            panier.insert(id)
            gardes.remove(id)
        }
    }

    public mutating func garder(_ ids: some Sequence<String>) {
        for id in ids {
            gardes.insert(id)
            panier.remove(id)
        }
    }

    /// Oublie tout verdict sur ces clichés : ils redeviennent à trier.
    public mutating func oublier(_ ids: some Sequence<String>) {
        for id in ids {
            panier.remove(id)
            gardes.remove(id)
        }
    }

    /// Après une suppression réussie, ou quand la photothèque a changé sous nos
    /// pieds : on ne garde que ce qui existe encore.
    public mutating func restreindre(a existants: Set<String>) {
        panier.formIntersection(existants)
        gardes.formIntersection(existants)
    }
}

public struct Carnet: Codable, Sendable {
    public var qualites: [String: Qualite] = [:]
    public var paires: [Paire] = []
    /// Tout ce qui est passé par l'analyse, y compris ce qu'elle n'a pas pu lire.
    public var analyses: Set<String> = []
    /// Poids déjà mesurés : la pesée coûte, un fichier ne change pas de poids.
    public var poids: [String: Int64] = [:]

    public init() {}

    public mutating func oublier(_ ids: Set<String>) {
        for id in ids {
            qualites[id] = nil
            poids[id] = nil
        }
        analyses.subtract(ids)
        paires.removeAll { ids.contains($0.a) || ids.contains($0.b) }
    }
}

/// Lecture et écriture atomiques en JSON dans un dossier donné.
public enum Coffre {
    public static func lire<T: Decodable>(_ type: T.Type, _ nom: String, dans dossier: URL) throws -> T? {
        let url = dossier.appendingPathComponent(nom)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    public static func ecrire<T: Encodable>(_ valeur: T, _ nom: String, dans dossier: URL) throws {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(valeur)
        try data.write(to: dossier.appendingPathComponent(nom), options: .atomic)
    }
}
