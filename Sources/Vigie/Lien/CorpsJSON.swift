#if canImport(SwiftUI)
import Foundation

/// Une valeur JSON typée. Existe pour que les corps d'écriture ne passent jamais
/// par un dictionnaire hétérogène : `[String: Any]` compile, puis explose à
/// l'encodage sur le premier type que `JSONSerialization` ne connaît pas — à
/// l'exécution, sur le téléphone, sans débogueur.
public enum ValeurJSON: Encodable, Sendable, Equatable {
    case texte(String)
    case entier(Int)
    case decimal(Double)
    case booleen(Bool)
    case nul
    case liste([ValeurJSON])
    case objet([String: ValeurJSON])

    public func encode(to encodeur: Encoder) throws {
        var contenant = encodeur.singleValueContainer()
        switch self {
        case .texte(let valeur): try contenant.encode(valeur)
        case .entier(let valeur): try contenant.encode(valeur)
        case .decimal(let valeur): try contenant.encode(valeur)
        case .booleen(let valeur): try contenant.encode(valeur)
        case .nul: try contenant.encodeNil()
        case .liste(let valeurs): try contenant.encode(valeurs)
        case .objet(let champs): try contenant.encode(champs)
        }
    }
}

extension ValeurJSON: ExpressibleByStringLiteral {
    public init(stringLiteral valeur: String) { self = .texte(valeur) }
}

extension ValeurJSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral valeur: Int) { self = .entier(valeur) }
}

extension ValeurJSON: ExpressibleByFloatLiteral {
    public init(floatLiteral valeur: Double) { self = .decimal(valeur) }
}

extension ValeurJSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral valeur: Bool) { self = .booleen(valeur) }
}

extension ValeurJSON: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .nul }
}

/// Le corps d'une écriture. S'écrit comme un littéral :
/// `await client.ecrire(Route.messageFil(id), ["texte": saisie, "modele": nil])`
public struct CorpsJSON: Encodable, Sendable, Equatable, ExpressibleByDictionaryLiteral {
    public private(set) var champs: [String: ValeurJSON]

    public init(_ champs: [String: ValeurJSON] = [:]) {
        self.champs = champs
    }

    public init(dictionaryLiteral elements: (String, ValeurJSON)...) {
        champs = Dictionary(elements, uniquingKeysWith: { _, dernier in dernier })
    }

    /// Retire les champs `nul`. Certaines routes du harness distinguent
    /// « champ absent » (ne pas toucher) de « champ à null » (effacer) : on ne
    /// l'applique donc jamais d'office, seulement sur demande de l'appelant.
    public func sansNuls() -> CorpsJSON {
        CorpsJSON(champs.filter { $0.value != .nul })
    }

    public func encode(to encodeur: Encoder) throws {
        var contenant = encodeur.container(keyedBy: CleLibre.self)
        for (cle, valeur) in champs {
            try contenant.encode(valeur, forKey: CleLibre(cle))
        }
    }

    public func octets() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

/// Clé de codage construite à la volée — les noms de champs viennent du contrat
/// serveur, pas d'un type Swift.
private struct CleLibre: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ valeur: String) { stringValue = valeur }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
#endif
