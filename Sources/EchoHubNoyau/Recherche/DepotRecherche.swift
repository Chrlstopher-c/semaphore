import Foundation

/// La disponibilité du service de recherche web, MESURÉE à l'instant de
/// l'appel.
///
/// `☠` Pourquoi cette route mérite un écran alors que Chris ne cherche jamais
/// sur le web depuis l'app : c'est SearXNG qui alimente l'outil de recherche du
/// modèle. Quand il est éteint, le modèle n'échoue pas — il répond quand même,
/// avec ce qu'il croit savoir. Le symptôme est une réponse plausible et
/// périmée, exactement le mode de panne qu'aucun message d'erreur ne signale.
/// Savoir que le service est mort est la seule façon de lire une telle réponse
/// pour ce qu'elle est.
public struct SanteRecherche: Sendable, Decodable {
    public let disponible: Bool
    public let url: String
    public let latenceMs: Double?
    public let statutHttp: Int?
    /// Ce qui a été mesuré, en clair : code inattendu, erreur réseau, ou bilan
    /// de la sonde complète.
    public let detail: String

    /// « 142 ms ». `nil` quand la sonde n'a pas abouti — jamais 0, qui se
    /// lirait comme une réponse instantanée.
    public var latenceLisible: String? {
        latenceMs.map { String(format: "%.0f ms", $0) }
    }
}

/// La porte vers le domaine `recherche` du PC.
///
/// Seule la santé est exposée. La recherche elle-même est un outil du MODÈLE,
/// pas une fonction de l'app : la doubler ici ferait un second chemin vers le
/// même service, avec ses propres réglages à tenir à jour, pour un usage que
/// Chris n'a pas demandé.
public struct DepotRecherche: Sendable {
    let client: ClientEchoHub

    public init(client: ClientEchoHub) {
        self.client = client
    }

    /// `complet` va jusqu'à une recherche témoin — la seule façon de prouver
    /// que le format JSON est actif, et pas seulement que le port répond. Plus
    /// lent, donc réservé au geste explicite.
    public func sante(complet: Bool = false) async throws -> SanteRecherche {
        try await client.lire(
            SanteRecherche.self, "GET", "recherche/sante?complet=\(complet)"
        )
    }
}
