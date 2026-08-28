import Foundation

/// Un outil du registre du PC, tel que l'écran de sélection le présente.
public struct OutilDisponible: Sendable, Decodable, Identifiable, Hashable {
    public var id: String { nom }
    public let nom: String
    public let description: String
    /// Famille d'appartenance (`web`, `fichiers`, `execution`, `presentation`),
    /// posée par le registre du PC — seule source qui connaisse les outils
    /// réellement enregistrés.
    public let groupe: String
    /// Ce que la DÉCLARATION de cet outil coûte en tokens, mesuré avec le
    /// tokenizer du modèle chargé.
    ///
    /// `☠` `nil` quand aucun modèle ne l'est : une absence NOMMÉE, jamais un
    /// zéro. Un zéro se lirait « cet outil ne coûte rien », alors qu'un outil
    /// déclaré occupe la fenêtre à CHAQUE tour. C'est la règle écrite côté
    /// serveur, et l'écran doit la tenir aussi.
    public let tokensDefinition: Int?

    public init(nom: String, description: String, groupe: String, tokensDefinition: Int? = nil) {
        self.nom = nom
        self.description = description
        self.groupe = groupe
        self.tokensDefinition = tokensDefinition
    }
}

/// Les outils mis à disposition du modèle pour une conversation.
///
/// `☠` Trois états, pas deux. `nil` = TOUS ceux du registre, `[]` = AUCUN, une
/// liste = ceux-là. Les confondre priverait d'outils une conversation qui n'a
/// jamais choisi, ou en rendrait à celle qui les a tous coupés.
public struct SelectionOutils: Sendable, Codable, Equatable {
    public let outilsActifs: [String]?

    public init(outilsActifs: [String]? = nil) {
        self.outilsActifs = outilsActifs
    }

    /// `☠` Pas de valeur brute `"outils_actifs"` : `CodageJSON` pose
    /// `convertFromSnakeCase`, qui traduit la clé du JSON en `outilsActifs`
    /// AVANT de chercher le `CodingKey`. Un cas écrit en snake_case ne serait
    /// jamais trouvé, et la sélection retomberait silencieusement sur « tous ».
    private enum Cle: String, CodingKey {
        case outilsActifs
    }

    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.container(keyedBy: Cle.self)
        outilsActifs = try conteneur.decodeIfPresent([String].self, forKey: .outilsActifs)
    }

    /// `encode(to:)` manuel et `encodeNil` explicite : la synthèse Swift
    /// produirait `encodeIfPresent`, qui OMET la clé pour un `nil`. Ici le
    /// serveur lit l'absence comme « tous » — c'est le même résultat, mais par
    /// accident. Écrire `null` dit ce qu'on veut dire, et le dira encore si le
    /// serveur cesse un jour de traiter les deux pareil.
    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.container(keyedBy: Cle.self)
        if let outilsActifs {
            try conteneur.encode(outilsActifs, forKey: .outilsActifs)
        } else {
            try conteneur.encodeNil(forKey: .outilsActifs)
        }
    }

    /// Cet outil est-il servi au modèle ? `nil` veut dire « tous » : c'est la
    /// seule lecture qui ne se déduit pas de la liste.
    public func contient(_ nom: String) -> Bool {
        outilsActifs?.contains(nom) ?? true
    }

    /// La sélection obtenue en basculant un outil, à partir du catalogue complet.
    ///
    /// Rendre `nil` quand tout est coché n'est pas une optimisation : c'est la
    /// différence entre « je veux tous les outils » — y compris ceux que le PC
    /// enregistrera demain — et « je veux exactement ces sept-là ».
    public func basculant(_ nom: String, parmi catalogue: [String]) -> SelectionOutils {
        let actifs = catalogue.filter { $0 == nom ? !contient($0) : contient($0) }
        return SelectionOutils(outilsActifs: actifs.count == catalogue.count ? nil : actifs)
    }
}
