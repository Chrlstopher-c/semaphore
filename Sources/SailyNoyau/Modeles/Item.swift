import Foundation

/// La nature d'un élément capturé. Miroir exact de `ItemKind` dans
/// `saily/shared/src/contracts.ts` — l'ordre et les chaînes sont fixés côté
/// serveur, toute divergence casserait le décodage en silence.
public enum EspeceItem: String, Codable, Sendable, CaseIterable, Hashable {
    case note
    case lien = "link"
    case image
    case video
    case fichier = "file"
}

/// Un élément de la besace : note, lien, image, vidéo ou fichier.
///
/// `☠` Miroir à la lettre de `Item` (contracts.ts). Les clés JSON sont en
/// `camelCase` et correspondent une à une aux noms de propriété — d'où AUCUNE
/// stratégie de conversion dans `CodageJSON`. Les horodatages sont des NOMBRES
/// (millisecondes depuis l'époque, `Date.now()` côté Bun), jamais des chaînes
/// ISO : les modéliser en `Int` évite tout le champ de mines des formats de
/// date, et `since` se compare alors par simple `>`.
public struct Item: Codable, Sendable, Equatable, Identifiable, Hashable {
    public let id: String
    public let kind: EspeceItem
    /// Corps texte (note) ou légende accompagnant un blob/lien.
    public let text: String
    /// URL cible pour un lien, `nil` sinon.
    public let url: String?
    /// Nom du blob stocké côté serveur (image/vidéo/fichier), `nil` sinon.
    public let blob: String?
    /// Type MIME du blob, `nil` sinon.
    public let mime: String?
    public let tags: [String]
    public let pinned: Bool
    /// Millisecondes depuis l'époque.
    public let createdAt: Int
    /// Millisecondes depuis l'époque. C'est l'horloge de la synchro : `since`
    /// avance sur ce champ, et un upsert plus ancien ne remplace jamais un plus
    /// récent.
    public let updatedAt: Int
    /// Suppression logique : non `nil` = pierre tombale, propagée pour que
    /// l'effacement atteigne tous les clients. Un item ainsi marqué reste connu
    /// mais n'est plus visible.
    public let deletedAt: Int?

    public init(
        id: String, kind: EspeceItem, text: String, url: String?, blob: String?,
        mime: String?, tags: [String], pinned: Bool, createdAt: Int, updatedAt: Int,
        deletedAt: Int?
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.url = url
        self.blob = blob
        self.mime = mime
        self.tags = tags
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Vraie tant que l'item n'est pas une pierre tombale.
    public var vivant: Bool { deletedAt == nil }
}

/// Les champs qu'un client a le droit de poser lors d'un upsert. Miroir de
/// `ItemInput` (contracts.ts) : ni `createdAt`, ni `updatedAt`, ni `deletedAt`
/// — le serveur en est seul maître.
///
/// `☠` `url`, `mime` et `blob` sont émis EXPLICITEMENT, `null` compris (voir
/// `encode(to:)`). L'encodeur de Swift omet un optionnel `nil` par défaut ; or
/// le serveur lie `input.url` / `input.mime` directement à SQLite, et une clé
/// absente y arriverait en `undefined`. On écrit donc toujours la clé.
public struct ItemInput: Codable, Sendable, Equatable {
    public let id: String
    public let kind: EspeceItem
    public let text: String
    public let url: String?
    public let blob: String?
    public let mime: String?
    public let tags: [String]
    public let pinned: Bool

    public init(
        id: String, kind: EspeceItem, text: String, url: String? = nil,
        blob: String? = nil, mime: String? = nil, tags: [String] = [], pinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.url = url
        self.blob = blob
        self.mime = mime
        self.tags = tags
        self.pinned = pinned
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, text, url, blob, mime, tags, pinned
    }

    public func encode(to encoder: any Encoder) throws {
        var bac = encoder.container(keyedBy: CodingKeys.self)
        try bac.encode(id, forKey: .id)
        try bac.encode(kind, forKey: .kind)
        try bac.encode(text, forKey: .text)
        // `encode` d'un optionnel omet la clé quand c'est `nil` ; on veut la clé
        // avec `null`. `encodeIfPresent` ne conviendrait donc pas.
        try bac.encode(url, forKey: .url)
        try bac.encode(blob, forKey: .blob)
        try bac.encode(mime, forKey: .mime)
        try bac.encode(tags, forKey: .tags)
        try bac.encode(pinned, forKey: .pinned)
    }

    /// L'entrée d'upsert reconstruite depuis un item connu, pour rejouer un
    /// changement (épingler, retaguer) sans réinventer ses champs.
    public init(depuis item: Item) {
        self.init(
            id: item.id, kind: item.kind, text: item.text, url: item.url,
            blob: item.blob, mime: item.mime, tags: item.tags, pinned: item.pinned
        )
    }
}
