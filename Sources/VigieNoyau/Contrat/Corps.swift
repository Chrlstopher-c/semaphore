import Foundation

// Responsabilité : les corps de requête et de réponse des routes de session, machine et appairage.
// Miroir des schémas du relais (`CorpsMode`, `CorpsEffort`…) : chaque corps ne porte que ce que la route attend.

public struct CorpsTexte: Encodable, Sendable, Equatable {
    public let texte: String
    public init(texte: String) { self.texte = texte }
}

/// Une pièce jointe d'un message (`PieceJointe` du relais) : 3 au plus, 3 Mio chacune avant base64.
public struct PieceJointe: Codable, Sendable, Equatable {
    public static let nombreMax = 3
    public static let tailleMax = 3 * 1024 * 1024
    public let nom: String
    public let mime: String
    public let base64: String
    public init(nom: String, mime: String, base64: String) {
        self.nom = nom
        self.mime = mime
        self.base64 = base64
    }
}

/// Un message avec ses pièces ; `pieces` est omis quand il n'y en a pas.
public struct CorpsMessage: Encodable, Sendable, Equatable {
    public let texte: String
    public let pieces: [PieceJointe]?
    public init(texte: String, pieces: [PieceJointe]) {
        self.texte = texte
        self.pieces = pieces.isEmpty ? nil : pieces
    }
}

public struct CorpsModele: Encodable, Sendable, Equatable {
    public let modele: String
    public init(modele: String) { self.modele = modele }
}

/// L'effort est toujours envoyé, `null` compris : c'est ce qui remet l'effort au défaut du modèle.
public struct CorpsEffort: Encodable, Sendable, Equatable {
    public let effort: String?

    public init(effort: String?) { self.effort = effort }

    public func encode(to encodeur: Encoder) throws {
        var c = encodeur.container(keyedBy: CodingKeys.self)
        if let effort {
            try c.encode(effort, forKey: .effort)
        } else {
            try c.encodeNil(forKey: .effort)
        }
    }

    private enum CodingKeys: String, CodingKey { case effort }
}

public struct CorpsMode: Encodable, Sendable, Equatable {
    public let mode: String
    public init(mode: String) { self.mode = mode }
}

public struct CorpsTitre: Encodable, Sendable, Equatable {
    public let titre: String
    public init(titre: String) { self.titre = titre }
}

public struct CorpsActif: Encodable, Sendable, Equatable {
    public let actif: Bool
    public init(actif: Bool) { self.actif = actif }
}

public struct CorpsAppairage: Encodable, Sendable, Equatable {
    public let code: String
    public let nom: String
    public init(code: String, nom: String) {
        self.code = code
        self.nom = nom
    }
}

/// Réponse de l'appairage : la clé de l'appareil, à garder dans le trousseau.
public struct ReponseAppairage: Decodable, Sendable, Equatable {
    public let cle: String
}
