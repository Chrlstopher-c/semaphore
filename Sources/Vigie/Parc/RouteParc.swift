#if canImport(SwiftUI)
import Foundation

/// Les destinations poussées à l'intérieur du domaine Parc.
enum RouteParc: Hashable {
    case equipe(String)
    /// Le fil d'un sous-agent : mission, puis identifiant d'agent.
    case sousAgent(String, String)
}
#endif
