import Foundation

/// L'interface publique du domaine `Outils` côté réseau : ce que le PC sait
/// faire, et ce qu'une conversation l'autorise à faire.
public struct DepotOutils: Sendable {
    let client: ClientEchoHub

    public init(client: ClientEchoHub) {
        self.client = client
    }

    /// Le registre du PC, groupes et coûts compris.
    public func catalogue() async throws -> [OutilDisponible] {
        try await client.lire([OutilDisponible].self, "GET", "chat/outils")
    }

    public func selection(_ identifiant: String) async throws -> SelectionOutils {
        try await client.lire(
            SelectionOutils.self, "GET", "chat/conversations/\(identifiant)/outils"
        )
    }

    /// Remplace la sélection. Le serveur accepte un nom inconnu puis l'ignore à
    /// l'usage : refuser à l'enregistrement ferait perdre toute une sélection
    /// pour un seul outil renommé entre-temps.
    @discardableResult
    public func definir(
        _ identifiant: String, _ selection: SelectionOutils
    ) async throws -> SelectionOutils {
        let corps = try CodageJSON.encodeur().encode(selection)
        return try await client.lire(
            SelectionOutils.self, "PATCH", "chat/conversations/\(identifiant)/outils", corps: corps
        )
    }
}
