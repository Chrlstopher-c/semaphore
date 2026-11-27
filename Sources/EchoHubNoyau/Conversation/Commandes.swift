import Foundation

/// Une commande du chat (`GET /chat/commandes`) : `/compact`, `/clear`…
public struct DefinitionCommande: Sendable, Decodable, Equatable, Identifiable {
    public let nom: String
    public let usage: String
    public let description: String
    /// Vrai si la commande accepte un texte après son nom (`/compact garde les endpoints`).
    public let arguments: Bool
    public var id: String { nom }

    public init(nom: String, usage: String, description: String, arguments: Bool) {
        self.nom = nom
        self.usage = usage
        self.description = description
        self.arguments = arguments
    }
}

/// Un `/clear` : le modèle ne voit plus rien au-dessus de `ancreMessageId`. Annulable.
public struct InfoEffacement: Sendable, Decodable, Equatable, Identifiable {
    public let id: String
    public let ancreMessageId: String
    public let creeLe: Date
}

/// Réponse du `POST …/commandes` : `effacement` n'existe que pour `/clear`.
public struct ReponseCommande: Sendable, Decodable, Equatable {
    public let commandeId: String
    public let nom: String
    public let effacement: InfoEffacement?
}

/// Lecture PURE de la saisie, comme `analyse.ts` du web : une commande commence au tout premier
/// caractère par « / » ; « //texte » échappe et part tel quel avec un seul « / ».
public enum AnalyseSaisie: Sendable, Equatable {
    case texte
    case litteral(String)
    case commande(nom: String, arguments: String)

    public init(_ saisie: String) {
        guard saisie.hasPrefix("/") else { self = .texte; return }
        if saisie.hasPrefix("//") { self = .litteral(String(saisie.dropFirst())); return }
        let corps = saisie.dropFirst()
        let nom = corps.prefix { !$0.isWhitespace }
        let reste = corps.dropFirst(nom.count).trimmingCharacters(in: .whitespacesAndNewlines)
        self = .commande(nom: nom.lowercased(), arguments: reste)
    }

    /// Le nom en cours de frappe (« comp » pour « /comp »), ou `nil` si la palette n'a rien à proposer.
    public static func nomEnFrappe(_ saisie: String) -> String? {
        guard saisie.hasPrefix("/"), !saisie.hasPrefix("//"), !saisie.contains(where: \.isWhitespace)
        else { return nil }
        return String(saisie.dropFirst()).lowercased()
    }

    /// Celles qui commencent par le préfixe d'abord, puis celles qui le contiennent.
    public static func filtrer(_ catalogue: [DefinitionCommande], _ prefixe: String) -> [DefinitionCommande] {
        catalogue.filter { $0.nom.hasPrefix(prefixe) }
            + catalogue.filter { !$0.nom.hasPrefix(prefixe) && $0.nom.contains(prefixe) }
    }

    /// Texte posé quand on choisit une commande : l'espace invite aux arguments.
    public static func completion(_ definition: DefinitionCommande) -> String {
        definition.arguments ? "/\(definition.nom) " : "/\(definition.nom)"
    }
}

extension DepotConversations {
    public func catalogueCommandes() async throws -> [DefinitionCommande] {
        try await client.lire([DefinitionCommande].self, "GET", "chat/commandes")
    }

    /// `/compact` répond 202 et diffuse ses étapes dans le flux (`commande`) ; `/clear` répond 200
    /// avec l'effacement posé.
    public func executerCommande(_ identifiant: String, nom: String, arguments: String) async throws -> ReponseCommande {
        let corps = try CodageJSON.encodeur().encode(["nom": nom, "arguments": arguments])
        return try await client.lire(
            ReponseCommande.self, "POST", "chat/conversations/\(identifiant)/commandes", corps: corps
        )
    }

    public func effacements(_ identifiant: String) async throws -> [InfoEffacement] {
        try await client.lire([InfoEffacement].self, "GET", "chat/conversations/\(identifiant)/effacements")
    }

    public func annulerEffacement(_ identifiant: String, effacement: String) async throws {
        try await client.executer("DELETE", "chat/conversations/\(identifiant)/effacements/\(effacement)")
    }

    /// Glisse un message à l'agent qui travaille : lu à la fin de son étape en cours. `false` = aucune
    /// génération en cours, l'appelant l'envoie alors comme un message.
    public func glisserConsigne(_ identifiant: String, texte: String) async throws -> Bool {
        struct Corps: Encodable { let id: String; let texte: String }
        struct Reponse: Decodable { let acceptee: Bool }
        let corps = try CodageJSON.encodeur().encode(Corps(id: UUID().uuidString, texte: texte))
        return try await client.lire(
            Reponse.self, "POST", "chat/conversations/\(identifiant)/consignes", corps: corps
        ).acceptee
    }
}
