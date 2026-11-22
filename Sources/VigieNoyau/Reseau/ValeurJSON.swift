import Foundation

// Responsabilité : JSON sans perte — une valeur lue puis réécrite garde chaque champ, même inconnu.
// La charte est gardée telle quelle : une édition ne jette jamais un champ d'une version plus récente.

/// Valeur JSON. Un nombre entier s'écrit sans « .0 ». L'ordre des clés d'objet n'est pas porté.
public indirect enum ValeurJSON: Sendable, Equatable, Codable {
    case objet([String: ValeurJSON])
    case tableau([ValeurJSON])
    case texte(String)
    case nombre(Double)
    case booleen(Bool)
    case nul

    public init(from decodeur: Decoder) throws {
        let conteneur = try decodeur.singleValueContainer()
        if conteneur.decodeNil() {
            self = .nul
        } else if let booleen = try? conteneur.decode(Bool.self) {
            self = .booleen(booleen)
        } else if let nombre = try? conteneur.decode(Double.self) {
            self = .nombre(nombre)
        } else if let texte = try? conteneur.decode(String.self) {
            self = .texte(texte)
        } else if let tableau = try? conteneur.decode([ValeurJSON].self) {
            self = .tableau(tableau)
        } else {
            self = .objet(try conteneur.decode([String: ValeurJSON].self))
        }
    }

    public func encode(to codeur: Encoder) throws {
        var conteneur = codeur.singleValueContainer()
        switch self {
        case .objet(let objet): try conteneur.encode(objet)
        case .tableau(let tableau): try conteneur.encode(tableau)
        case .texte(let texte): try conteneur.encode(texte)
        case .nombre(let nombre):
            if let entier = ValeurJSON.entierExact(nombre) {
                try conteneur.encode(entier)
            } else {
                try conteneur.encode(nombre)
            }
        case .booleen(let booleen): try conteneur.encode(booleen)
        case .nul: try conteneur.encodeNil()
        }
    }

    /// Texte JSON compact, clés triées : c'est ce texte exact que la signature couvre.
    public func texteJSON() throws -> String {
        let codeur = JSONEncoder()
        codeur.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try codeur.encode(self), as: UTF8.self)
    }

    /// Lit un texte JSON quelconque.
    public static func lire(_ texte: String) throws -> ValeurJSON {
        try JSONDecoder().decode(ValeurJSON.self, from: Data(texte.utf8))
    }

    public subscript(cle: String) -> ValeurJSON? {
        guard case .objet(let objet) = self else { return nil }
        return objet[cle]
    }

    /// Le nombre, s'il est un entier exact représentable.
    static func entierExact(_ nombre: Double) -> Int? {
        guard nombre.isFinite, nombre.rounded() == nombre, abs(nombre) < 9_007_199_254_740_992 else { return nil }
        return Int(nombre)
    }
}

/// Lecture typée d'un champ JSON : un champ absent ou mal typé fait échouer la lecture, jamais une valeur devinée.
enum Lu {
    static let base64url = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    static func illisible(_ cle: String) -> ErreurReseau { ErreurReseau(message: "charte illisible : \(cle)") }

    static func objet(_ valeur: ValeurJSON?, _ cle: String) throws -> [String: ValeurJSON] {
        guard case .objet(let objet)? = valeur else { throw illisible(cle) }
        return objet
    }

    static func tableau(_ valeur: ValeurJSON?, _ cle: String) throws -> [ValeurJSON] {
        guard case .tableau(let tableau)? = valeur else { throw illisible(cle) }
        return tableau
    }

    static func texte(_ valeur: ValeurJSON?, _ cle: String) throws -> String {
        guard case .texte(let chaine)? = valeur else { throw illisible(cle) }
        return chaine
    }

    static func texteMax(_ valeur: ValeurJSON?, _ cle: String, _ max: Int) throws -> String {
        let chaine = try texte(valeur, cle)
        guard chaine.utf16.count <= max else { throw illisible(cle) }
        return chaine
    }

    static func texteOuNul(_ valeur: ValeurJSON?, _ cle: String, max: Int) throws -> String? {
        if case .nul? = valeur { return nil }
        return try texteMax(valeur, cle, max)
    }

    static func booleen(_ valeur: ValeurJSON?, _ cle: String) throws -> Bool {
        guard case .booleen(let booleen)? = valeur else { throw illisible(cle) }
        return booleen
    }

    static func entier(_ valeur: ValeurJSON?, _ cle: String) throws -> Int {
        guard case .nombre(let nombre)? = valeur, let entier = ValeurJSON.entierExact(nombre) else {
            throw illisible(cle)
        }
        return entier
    }

    static func entierDans(_ valeur: ValeurJSON?, _ cle: String, _ bornes: ClosedRange<Int>) throws -> Int {
        let entier = try entier(valeur, cle)
        guard bornes.contains(entier) else { throw illisible(cle) }
        return entier
    }

    static func entierOuNul(_ valeur: ValeurJSON?, _ cle: String) throws -> Int? {
        if case .nul? = valeur { return nil }
        return try entier(valeur, cle)
    }

    static func identifiant(_ valeur: ValeurJSON?, _ cle: String) throws -> String {
        let chaine = try texte(valeur, cle)
        guard estIdentifiant(chaine) else { throw illisible(cle) }
        return chaine
    }

    /// Identifiant de membre ou de réseau : 12 caractères hexadécimaux minuscules.
    static func estIdentifiant(_ chaine: String) -> Bool {
        estSuite(chaine, longueur: 12, alphabet: "0123456789abcdef")
    }

    /// Identité publique : 86 caractères base64url (32 octets X25519 puis 32 octets Ed25519).
    static func identite(_ valeur: ValeurJSON?, _ cle: String) throws -> String {
        let chaine = try texte(valeur, cle)
        guard estSuite(chaine, longueur: 86, alphabet: String(base64url)) else { throw illisible(cle) }
        return chaine
    }

    static func nom(_ valeur: ValeurJSON?, _ cle: String) throws -> String {
        let net = try texte(valeur, cle).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !net.isEmpty, net.utf16.count <= 80 else { throw illisible(cle) }
        return net
    }

    static func estSuite(_ chaine: String, longueur: Int, alphabet: String) -> Bool {
        chaine.utf8.count == longueur && chaine.allSatisfy { alphabet.contains($0) }
    }
}
