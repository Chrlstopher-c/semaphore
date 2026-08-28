import Foundation

/// Du JSON transporté SANS être compris.
///
/// `☠` C'est ce qui permet de charger un modèle depuis le téléphone sans porter
/// les DTO du planificateur. Le plan de chargement d'EchoHub v2 est une
/// structure profonde — `ValeurJustifiee<T>` sur sept axes, budget mémoire,
/// variables d'environnement, éjections requises — et l'app a décidé de ne PAS
/// l'afficher (`ARCHITECTURE.md`, § « Le plan de chargement n'est pas
/// affiché »). Le porter en Swift serait écrire trois cents lignes de types
/// pour ne rien en montrer, et les faire diverger à la première évolution du
/// serveur.
///
/// L'app relit donc le plan que le PC vient de rendre et le lui repose tel
/// quel. Le planificateur reste le seul à connaître la VRAM, ce qui est
/// exactement la règle : ne jamais inventer un plan côté iPhone.
public enum ValeurJSON: Sendable, Codable, Equatable {
    case nul
    case booleen(Bool)
    /// Distinct de `nombre` : un `couches_gpu` réémis en `41.0` là où le serveur
    /// attend un entier serait refusé par pydantic, sur une erreur de validation
    /// qui ne dirait rien du voyage aller-retour.
    case entier(Int)
    case nombre(Double)
    case texte(String)
    case liste([ValeurJSON])
    case objet([String: ValeurJSON])

    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.singleValueContainer()
        if conteneur.decodeNil() {
            self = .nul
        } else if let valeur = try? conteneur.decode(Bool.self) {
            self = .booleen(valeur)
        } else if let valeur = try? conteneur.decode(Int.self) {
            self = .entier(valeur)
        } else if let valeur = try? conteneur.decode(Double.self) {
            self = .nombre(valeur)
        } else if let valeur = try? conteneur.decode(String.self) {
            self = .texte(valeur)
        } else if let valeur = try? conteneur.decode([ValeurJSON].self) {
            self = .liste(valeur)
        } else {
            self = .objet(try conteneur.decode([String: ValeurJSON].self))
        }
    }

    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.singleValueContainer()
        switch self {
        case .nul: try conteneur.encodeNil()
        case .booleen(let valeur): try conteneur.encode(valeur)
        case .entier(let valeur): try conteneur.encode(valeur)
        case .nombre(let valeur): try conteneur.encode(valeur)
        case .texte(let valeur): try conteneur.encode(valeur)
        case .liste(let valeur): try conteneur.encode(valeur)
        case .objet(let valeur): try conteneur.encode(valeur)
        }
    }

    /// La valeur d'une clé, quand c'est un objet. `nil` sinon — jamais une
    /// erreur : ce type sert à traverser, pas à valider.
    public subscript(cle: String) -> ValeurJSON? {
        if case .objet(let champs) = self { return champs[cle] }
        return nil
    }

    public var texteOuNil: String? {
        if case .texte(let valeur) = self { return valeur }
        return nil
    }

    /// `☠` Accepte aussi un `nombre` de valeur entière : pydantic sérialise un
    /// champ calculé en flottant selon le chemin de calcul. Refuser `41.0`
    /// ferait échouer un plan sur une valeur pourtant juste ; `41.5`, lui, est
    /// bien refusé — ce n'est pas un entier.
    public var entierOuNil: Int? {
        switch self {
        case .entier(let valeur): return valeur
        case .nombre(let valeur) where valeur == valeur.rounded(): return Int(valeur)
        default: return nil
        }
    }

    public var nombreOuNil: Double? {
        switch self {
        case .entier(let valeur): return Double(valeur)
        case .nombre(let valeur): return valeur
        default: return nil
        }
    }

    public var booleenOuNil: Bool? {
        if case .booleen(let valeur) = self { return valeur }
        return nil
    }

    public var listeOuNil: [ValeurJSON]? {
        if case .liste(let valeur) = self { return valeur }
        return nil
    }

    public var estNul: Bool { self == .nul }

    /// Descend une suite de clés d'un coup. `nil` dès qu'un maillon manque ou
    /// n'est pas un objet — jamais une erreur, comme le sous-script.
    public func chemin(_ cles: String...) -> ValeurJSON? {
        cles.reduce(self as ValeurJSON?) { courante, cle in courante?[cle] }
    }
}

/// `☠` `ValeurJSON` traverse SANS la conversion snake_case du reste du contrat.
/// Les clés d'un plan (`couches_gpu`, `type_cache_kv`) sont déjà celles du
/// serveur ; les faire passer par `convertFromSnakeCase` les rendrait en
/// `couchesGpu`, et `convertToSnakeCase` les réémettrait en `couches_gpu` —
/// vrai pour celle-là, faux dès qu'une clé porte un sigle
/// (`utilisation_memoire_gpu` deviendrait `utilisation_memoire_gpu` mais
/// `flash_attention` → `flashAttention` → `flash_attention` seulement par
/// chance). Un aller-retour opaque doit rester opaque.
public enum CodageOpaque {
    public static func decodeur() -> JSONDecoder { JSONDecoder() }
    public static func encodeur() -> JSONEncoder { JSONEncoder() }
}
