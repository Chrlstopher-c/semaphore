import Foundation

/// Les projets de l'agent (`api-projet.ts` du web) : un dossier de travail confié à une conversation.
public struct Projet: Sendable, Decodable, Equatable, Identifiable {
    public let nom: String
    /// Secondes depuis l'époque.
    public let modifieLe: Double
    public let instantanes: Bool
    public var id: String { nom }
}

public struct CatalogueProjets: Sendable, Decodable, Equatable {
    /// Faux si le mode projet n'est pas configuré sur le PC.
    public let actif: Bool
    public let racine: String?
    public let projets: [Projet]
}

public struct Instantane: Sendable, Decodable, Equatable, Identifiable {
    public let sha: String
    public let date: Double
    public let message: String
    public var id: String { sha }
}

public struct EtatApercu: Sendable, Decodable, Equatable {
    public let port: Int?
    public let ports: [Int]
    public let url: String
}

public struct EntreeArbre: Sendable, Decodable, Equatable, Identifiable {
    public let chemin: String
    public let taille: Int
    public var id: String { chemin }
}

public struct ArbreProjet: Sendable, Decodable, Equatable {
    public let fichiers: [EntreeArbre]
    public let tronque: Bool
}

public struct ContenuFichier: Sendable, Decodable, Equatable {
    public let chemin: String
    public let taille: Int
    public let contenu: String?
    public let binaire: Bool
    public let tronque: Bool
}

public struct Modification: Sendable, Decodable, Equatable, Identifiable {
    /// `A` ajouté, `M` modifié, `D` supprimé.
    public let chemin: String
    public let etat: String
    public let ajouts: Int?
    public let suppressions: Int?
    public var id: String { chemin }
}

public struct ModificationsProjet: Sendable, Decodable, Equatable {
    public let reference: Instantane?
    public let fichiers: [Modification]
}

public struct DiffFichier: Sendable, Decodable, Equatable {
    public let chemin: String
    public let diff: String
    public let tronque: Bool
}

public struct DepotProjets: Sendable {
    let client: ClientEchoHub

    public init(client: ClientEchoHub) {
        self.client = client
    }

    /// Le nom qu'accepte le serveur : minuscules, chiffres, `.`, `_`, `-`, 63 caractères au plus.
    public static func nomValide(_ nom: String) -> Bool {
        nom.range(of: #"^[a-z0-9][a-z0-9._-]{0,62}$"#, options: .regularExpression) != nil
    }

    public func lister() async throws -> CatalogueProjets {
        try await client.lire(CatalogueProjets.self, "GET", "projets")
    }

    public func creer(_ nom: String) async throws -> Projet {
        try await client.lire(Projet.self, "POST", "projets", corps: try json(["nom": nom]))
    }

    public func instantanes(_ nom: String) async throws -> [Instantane] {
        try await client.lire([Instantane].self, "GET", "projets/\(nom)/instantanes")
    }

    public func restaurer(_ nom: String, instantane sha: String) async throws {
        try await client.executer("POST", "projets/\(nom)/instantanes/\(sha)/restaurer", corps: Data("{}".utf8))
    }

    /// Le projet confié à la conversation, `nil` si aucun.
    public func projet(deLaConversation identifiant: String) async throws -> String? {
        try await client.lire(Liaison.self, "GET", "chat/conversations/\(identifiant)/projet").projet
    }

    /// Confie un projet (ou le retire avec `nil`) ; rend la liaison écrite.
    public func lier(_ identifiant: String, projet: String?) async throws -> String? {
        try await client.lire(
            Liaison.self, "PATCH", "chat/conversations/\(identifiant)/projet", corps: try json(Liaison(projet: projet))
        ).projet
    }

    /// « Haiku écrit le code » : le modèle local pilote, Claude Haiku code sans rien voir du projet.
    public func hybride(_ identifiant: String) async throws -> Bool {
        try await client.lire(Hybride.self, "GET", "chat/conversations/\(identifiant)/hybride").hybride
    }

    public func changerHybride(_ identifiant: String, _ actif: Bool) async throws -> Bool {
        try await client.lire(
            Hybride.self, "PATCH", "chat/conversations/\(identifiant)/hybride", corps: try json(Hybride(hybride: actif))
        ).hybride
    }

    public func apercu(_ nom: String) async throws -> EtatApercu {
        try await client.lire(EtatApercu.self, "GET", "projets/\(nom)/apercu")
    }

    public func pointerApercu(_ nom: String, port: Int) async throws -> EtatApercu {
        try await client.lire(EtatApercu.self, "POST", "projets/\(nom)/apercu", corps: try json(["port": port]))
    }

    public func arbre(_ nom: String) async throws -> ArbreProjet {
        try await client.lire(ArbreProjet.self, "GET", "projets/\(nom)/arbre")
    }

    public func fichier(_ nom: String, chemin: String) async throws -> ContenuFichier {
        try await client.lire(ContenuFichier.self, "GET", "projets/\(nom)/fichier?chemin=\(Self.encoder(chemin))")
    }

    public func modifications(_ nom: String) async throws -> ModificationsProjet {
        try await client.lire(ModificationsProjet.self, "GET", "projets/\(nom)/modifications")
    }

    public func diff(_ nom: String, chemin: String) async throws -> DiffFichier {
        try await client.lire(DiffFichier.self, "GET", "projets/\(nom)/diff?chemin=\(Self.encoder(chemin))")
    }

    /// Une valeur de requête : tout ce qui n'est pas alphanumérique ou `-._~` est encodé (`/`, `&`, espaces…).
    static func encoder(_ valeur: String) -> String {
        valeur.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~")))
            ?? valeur
    }

    private struct Liaison: Codable { let projet: String? }
    private struct Hybride: Codable { let hybride: Bool }

    private func json(_ valeur: some Encodable) throws -> Data { try CodageJSON.encodeur().encode(valeur) }
}
