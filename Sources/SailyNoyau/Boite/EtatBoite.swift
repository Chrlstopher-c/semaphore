import Foundation

/// L'état pur de la besace : tous les items connus (pierres tombales
/// comprises), l'horloge de synchro, et la file des écritures faites hors
/// ligne. AUCUN réseau, AUCune dépendance UI — c'est le cœur éprouvé par
/// `swift test`, la seule preuve automatique du monde Saily.
///
/// `☠` Idempotence par `id` ET par `updatedAt` : un même upsert rejoué (file
/// offline, écho du socket) ne fait rien, et un upsert PLUS ANCIEN ne remplace
/// jamais un plus récent. C'est ce qui rend la reconnexion et le rejeu sûrs.
public struct EtatBoite: Sendable, Equatable {
    /// Tous les items par id, y compris les supprimés (deletedAt non nil) : la
    /// pierre tombale doit survivre pour qu'un delta ultérieur la connaisse.
    public private(set) var parId: [String: Item]
    /// Le plus grand `updatedAt` appliqué. C'est le `since` à renvoyer au
    /// serveur pour ne demander que le delta — reconnexion comprise.
    public private(set) var since: Int
    /// Les écritures émises pendant une coupure, à rejouer à la reconnexion.
    /// Bornée : au-delà de `plafondFile`, la plus ancienne cède la place.
    public private(set) var enAttente: [MessageClient]

    /// `☠` Une file offline non bornée est une fuite mémoire déguisée : hors
    /// ligne longtemps, chaque capture s'y empile sans limite. Le plafond garde
    /// les plus RÉCENTES — ce sont elles qui comptent, et l'idempotence par id
    /// fait que perdre une version intermédiaire d'un même item est sans effet.
    public static let plafondFile = 500

    public init(
        parId: [String: Item] = [:], since: Int = 0, enAttente: [MessageClient] = []
    ) {
        self.parId = parId
        self.since = since
        self.enAttente = enAttente
    }

    // MARK: - Lecture

    /// Les items à montrer : vivants, épingles en tête, puis les plus récemment
    /// modifiés. Tri total (l'`id` départage) pour un ordre stable d'un relevé
    /// à l'autre — sans quoi la liste tremblerait à chaque égalité de date.
    public var visibles: [Item] {
        parId.values
            .filter(\.vivant)
            .sorted { gauche, droite in
                if gauche.pinned != droite.pinned { return gauche.pinned }
                if gauche.updatedAt != droite.updatedAt { return gauche.updatedAt > droite.updatedAt }
                return gauche.id < droite.id
            }
    }

    /// L'ensemble des tags portés par les items vivants, ordonné.
    public var tags: [String] {
        Set(parId.values.filter(\.vivant).flatMap(\.tags)).sorted()
    }

    // MARK: - Application des deltas

    /// Remplace/complète par un lot d'items (snapshot d'ouverture ou delta
    /// `GET /items`). Chaque item passe par la même règle d'ancienneté.
    public mutating func appliquer(snapshot items: [Item]) {
        for item in items { appliquer(item: item) }
    }

    /// Applique un item, tombale ou vivant. Ne remplace que si strictement plus
    /// récent — l'égalité laisse l'existant en place (rejeu sans effet).
    public mutating func appliquer(item: Item) {
        if let connu = parId[item.id], connu.updatedAt >= item.updatedAt { return }
        parId[item.id] = item
        if item.updatedAt > since { since = item.updatedAt }
    }

    /// Applique une suppression reçue par le socket (`{id, deletedAt}`). Sur un
    /// item connu, pose la pierre tombale ; sur un id inconnu, en synthétise une
    /// pour que le `since` avance et qu'un futur snapshot ne le ressuscite pas.
    public mutating func appliquerSuppression(id: String, deletedAt: Int) {
        if let connu = parId[id] {
            guard deletedAt > connu.updatedAt else { return }
            parId[id] = Item(
                id: connu.id, kind: connu.kind, text: connu.text, url: connu.url,
                blob: connu.blob, mime: connu.mime, tags: connu.tags, pinned: connu.pinned,
                createdAt: connu.createdAt, updatedAt: deletedAt, deletedAt: deletedAt
            )
        } else {
            parId[id] = Item(
                id: id, kind: .note, text: "", url: nil, blob: nil, mime: nil,
                tags: [], pinned: false, createdAt: deletedAt, updatedAt: deletedAt,
                deletedAt: deletedAt
            )
        }
        if deletedAt > since { since = deletedAt }
    }

    /// Applique un message serveur, en ignorant l'écho de nos propres écritures.
    /// Rend `true` si l'état a pu changer (utile pour ne notifier que si besoin).
    @discardableResult
    public mutating func appliquer(_ message: MessageServeur, clientId: String) -> Bool {
        switch message {
        case let .snapshot(items, _):
            appliquer(snapshot: items)
            return true
        case let .upsert(item, origin):
            if Self.doitIgnorer(origin: origin, clientId: clientId) { return false }
            appliquer(item: item)
            return true
        case let .delete(id, deletedAt, origin):
            if Self.doitIgnorer(origin: origin, clientId: clientId) { return false }
            appliquerSuppression(id: id, deletedAt: deletedAt)
            return true
        case .pong:
            return false
        }
    }

    /// L'écho de ses propres écritures se reconnaît à `origin == clientId`.
    public static func doitIgnorer(origin: String, clientId: String) -> Bool {
        origin == clientId
    }

    // MARK: - Optimisme local et file offline

    /// Pose localement le résultat d'une capture AVANT l'aller-retour serveur,
    /// pour que l'inbox réagisse tout de suite. `maintenant` = horloge locale en
    /// ms ; le serveur réécrira `updatedAt`, et l'idempotence encaisse l'écart.
    public mutating func poserLocalement(_ input: ItemInput, maintenant: Int) {
        let ancien = parId[input.id]
        parId[input.id] = Item(
            id: input.id, kind: input.kind, text: input.text, url: input.url,
            blob: input.blob, mime: input.mime, tags: input.tags, pinned: input.pinned,
            createdAt: ancien?.createdAt ?? maintenant, updatedAt: maintenant, deletedAt: nil
        )
        if maintenant > since { since = maintenant }
    }

    /// Marque localement un item supprimé (optimisme), avant diffusion.
    public mutating func supprimerLocalement(id: String, maintenant: Int) {
        appliquerSuppression(id: id, deletedAt: maintenant)
    }

    /// Empile une écriture à rejouer plus tard. Bornée par `plafondFile`.
    public mutating func enfiler(_ message: MessageClient) {
        enAttente.append(message)
        if enAttente.count > Self.plafondFile {
            enAttente.removeFirst(enAttente.count - Self.plafondFile)
        }
    }

    /// Vide la file et rend son contenu, pour le rejouer sur la connexion
    /// rétablie. L'ordre d'émission est préservé.
    public mutating func viderFile() -> [MessageClient] {
        let messages = enAttente
        enAttente.removeAll(keepingCapacity: true)
        return messages
    }
}
