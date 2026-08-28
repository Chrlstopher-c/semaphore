import Foundation

/// Ce que le bac à sable du PC garantit réellement, écrit UNE fois côté
/// serveur.
///
/// `☠` L'interface le rend tel quel — elle ne le réécrit ni ne l'embellit.
/// C'est la seule source : un texte recopié dans l'app finirait par promettre
/// des limites que le bac à sable n'applique plus, et une garantie de sécurité
/// périmée est pire qu'une garantie absente.
struct LimitesBac: Decodable {
    let texte: String
}

extension DepotOutils {

    /// Le texte des limites d'exécution, prêt à afficher. Vide quand le serveur
    /// n'a rien à dire — l'écran tait alors la section plutôt que d'annoncer
    /// une garantie qu'il ne connaît pas.
    public func limitesBac() async throws -> String {
        try await client.lire(LimitesBac.self, "GET", "outils/limites-bac").texte
    }
}
