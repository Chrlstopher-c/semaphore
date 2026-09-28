import Foundation

// L'accès à distance d'un appareil du parc : ses fichiers et ses terminaux, tels que le relais les rend
// (miroir de `commun/appareil.ts`). Tout passe par le relais : réseau local ou 4G, même chemin.

public struct EntreeFichier: Codable, Sendable, Identifiable, Equatable {
    public enum Genre: String, Codable, Sendable { case dossier, fichier, lien, autre }

    public let nom: String
    public let type: Genre
    public let taille: Double
    public let modifie: String
    public let cache: Bool

    public var id: String { nom }
}

public struct ListeDossier: Codable, Sendable, Equatable {
    public let chemin: String
    public let parent: String?
    public let accueil: String
    public let entrees: [EntreeFichier]
}

/// Ce qu'on montre d'un fichier : le texte s'édite, l'image s'affiche, le reste passe par QuickLook.
public enum ApercuFichier: Sendable, Equatable {
    case image, texte, markdown, quickLook

    /// Au-delà, un texte ne s'ouvre pas dans l'éditeur (même limite que le relais).
    public static let tailleMaxEdition: Double = 2 * 1024 * 1024

    private static let images: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tiff", "ico"]
    private static let textes: Set<String> = Set(("txt log csv tsv json jsonc yaml yml toml ini conf cfg env sh bash zsh fish "
        + "ts tsx js jsx mjs cjs py rb go rs swift kt java c h cpp hpp cs php lua sql html htm css scss xml svg vue "
        + "svelte gitignore dockerignore editorconfig service timer lock gradle properties").split(separator: " ").map(String.init))
    private static let nomsTextes: Set<String> = ["Dockerfile", "Makefile", "Caddyfile", "Procfile", "LICENSE", "README"]

    public static func extensionDe(_ nom: String) -> String {
        guard let point = nom.lastIndex(of: ".") else { return "" }
        return String(nom[nom.index(after: point)...]).lowercased()
    }

    public static func de(_ nom: String) -> ApercuFichier {
        let ext = extensionDe(nom)
        if images.contains(ext) { return .image }
        if ext == "md" || ext == "markdown" { return .markdown }
        if textes.contains(ext) || nomsTextes.contains(nom) || nom.hasPrefix(".") && !nom.dropFirst().contains(".") {
            return .texte
        }
        return .quickLook
    }

    public var editable: Bool { self == .texte || self == .markdown }
}

public enum CheminDistant {
    /// Joint un nom à un dossier distant (toujours des `/` : les postes sont sous Linux).
    public static func joindre(_ dossier: String, _ nom: String) -> String {
        dossier.hasSuffix("/") ? dossier + nom : dossier + "/" + nom
    }

    public static func nom(_ chemin: String) -> String {
        chemin.split(separator: "/").last.map(String.init) ?? chemin
    }
}

public struct CorpsChemin: Encodable, Sendable {
    public let chemin: String
    public init(chemin: String) { self.chemin = chemin }
}

public struct CorpsRenommer: Encodable, Sendable {
    public let de: String
    public let vers: String
    public init(de: String, vers: String) {
        self.de = de
        self.vers = vers
    }
}

extension Route {
    private static func requete(_ parametres: [(String, String)]) -> String {
        var c = URLComponents()
        c.queryItems = parametres.map { URLQueryItem(name: $0.0, value: $0.1) }
        // `+` et `&` survivent dans un chemin de fichier : on les encode aussi.
        return c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B") ?? ""
    }

    public static func fichiers(_ machine: String, chemin: String?) -> String {
        let base = "/api/machines/\(machine)/fichiers"
        guard let chemin else { return base }
        return base + "?" + requete([("chemin", chemin)])
    }

    public static func fichier(_ machine: String, chemin: String) -> String {
        "/api/machines/\(machine)/fichier?" + requete([("chemin", chemin)])
    }

    public static func supprimer(_ machine: String) -> String { "/api/machines/\(machine)/fichiers/supprimer" }
    public static func renommer(_ machine: String) -> String { "/api/machines/\(machine)/fichiers/renommer" }
    public static func creerDossier(_ machine: String) -> String { "/api/machines/\(machine)/fichiers/dossier" }

    /// Terminal à distance (WebSocket) : un shell dans `dossier`, ou attaché à la session tmux `tmux`.
    public static func terminal(_ machine: String, tmux: String? = nil, dossier: String? = nil,
                                colonnes: Int, lignes: Int) -> String {
        var p = [("machine", machine), ("colonnes", String(colonnes)), ("lignes", String(lignes))]
        if let tmux { p.append(("tmux", tmux)) }
        if let dossier { p.append(("dossier", dossier)) }
        return "/api/terminal?" + requete(p)
    }
}
