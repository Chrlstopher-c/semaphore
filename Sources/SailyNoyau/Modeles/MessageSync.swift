import Foundation

/// Ce qu'un client émet vers le serveur sur le WebSocket `/sync`. Miroir de
/// `ClientMessage` (contracts.ts).
///
/// `☠` Union taguée par `type`, comme côté TypeScript. L'encodage est écrit à
/// la main parce qu'un `enum` Swift à valeurs associées ne produit PAS
/// spontanément `{"type": "...", ...}` — et le serveur ne lit que cette forme.
public enum MessageClient: Sendable, Equatable {
    /// À l'ouverture : « voici qui je suis, envoie-moi le delta depuis `since` ».
    case hello(clientId: String, since: Int)
    case upsert(item: ItemInput, clientId: String)
    case delete(id: String, clientId: String)
    case ping

    private enum Cle: String, CodingKey {
        case type, clientId, since, item, id
    }
}

extension MessageClient: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var bac = encoder.container(keyedBy: Cle.self)
        switch self {
        case let .hello(clientId, since):
            try bac.encode("hello", forKey: .type)
            try bac.encode(clientId, forKey: .clientId)
            try bac.encode(since, forKey: .since)
        case let .upsert(item, clientId):
            try bac.encode("upsert", forKey: .type)
            try bac.encode(item, forKey: .item)
            try bac.encode(clientId, forKey: .clientId)
        case let .delete(id, clientId):
            try bac.encode("delete", forKey: .type)
            try bac.encode(id, forKey: .id)
            try bac.encode(clientId, forKey: .clientId)
        case .ping:
            try bac.encode("ping", forKey: .type)
        }
    }
}

/// Ce que le serveur pousse vers les clients. Miroir de `ServerMessage`
/// (contracts.ts).
///
/// `☠` `origin` porte le `clientId` de l'émetteur : c'est ce qui permet
/// d'ignorer l'écho de ses PROPRES écritures (voir `EtatBoite.doitIgnorer`).
/// Sans ce filtrage, une capture faite ici reviendrait par le socket et se
/// rappliquerait — inoffensif car idempotent, mais inutile.
public enum MessageServeur: Sendable, Equatable {
    case snapshot(items: [Item], serverTime: Int)
    case upsert(item: Item, origin: String)
    case delete(id: String, deletedAt: Int, origin: String)
    case pong(serverTime: Int)

    private enum Cle: String, CodingKey {
        case type, items, serverTime, item, origin, id, deletedAt
    }

    /// `☠` Un `type` inconnu n'est pas une erreur fatale : le serveur peut
    /// gagner un message que cette version d'app ne connaît pas encore. On rend
    /// `nil` et l'appelant l'ignore, plutôt que de faire tomber toute la
    /// réception sur une valeur en trop.
    public static func decoder(_ donnees: Data) -> MessageServeur? {
        try? JSONDecoder().decode(MessageServeur.self, from: donnees)
    }
}

extension MessageServeur: Decodable {
    public init(from decoder: any Decoder) throws {
        let bac = try decoder.container(keyedBy: Cle.self)
        let type = try bac.decode(String.self, forKey: .type)
        switch type {
        case "snapshot":
            self = .snapshot(
                items: try bac.decode([Item].self, forKey: .items),
                serverTime: try bac.decode(Int.self, forKey: .serverTime)
            )
        case "upsert":
            self = .upsert(
                item: try bac.decode(Item.self, forKey: .item),
                origin: try bac.decode(String.self, forKey: .origin)
            )
        case "delete":
            self = .delete(
                id: try bac.decode(String.self, forKey: .id),
                deletedAt: try bac.decode(Int.self, forKey: .deletedAt),
                origin: try bac.decode(String.self, forKey: .origin)
            )
        case "pong":
            self = .pong(serverTime: try bac.decode(Int.self, forKey: .serverTime))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: bac,
                debugDescription: "Type de message serveur inconnu : « \(type) »"
            )
        }
    }
}
