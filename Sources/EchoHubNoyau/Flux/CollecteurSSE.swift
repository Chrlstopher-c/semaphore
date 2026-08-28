import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Ce qu'une réponse en cours de lecture peut annoncer.
///
/// `URLResponse` n'est PAS `Sendable` : c'est le statut qui traverse, pas la
/// réponse. Une contrainte de Swift 6 strict qui tombe bien — l'app n'a besoin
/// que de ce nombre.
public enum SignalFlux: Sendable {
    case statut(Int)
    case octets(Data)
    /// Fin de transfert. `nil` = terminé normalement.
    case fin(String?)
}

/// Lit le corps d'une réponse HTTP au fil de l'eau.
///
/// `☠` Pourquoi un délégué `URLSession` et pas `URLSession.bytes(for:)`, qui
/// tiendrait en une ligne : `AsyncBytes` n'existe PAS dans la Foundation de
/// Linux. Le code qui l'utilise ne compile que sur Darwin — donc `swift test`,
/// seule preuve automatique de ce projet, ne le type-checke jamais. Le fichier
/// le plus critique du produit serait le seul jamais vérifié avant l'IPA.
/// Le chemin délégué existe sur les deux plateformes : il coûte cinquante
/// lignes et il est compilé à chaque test.
///
/// `☠` Le piège de Sillon, reformulé : une closure confiée à un framework
/// Apple. Ici la classe est `final`, ne porte qu'une propriété `let` `Sendable`
/// (la continuation), et conforme donc à `Sendable` SANS `@unchecked` — la
/// vérification reste au compilateur, pas à la relecture.
public final class CollecteurSSE: NSObject, URLSessionDataDelegate, Sendable {
    private let suite: AsyncStream<SignalFlux>.Continuation

    public init(suite: AsyncStream<SignalFlux>.Continuation) {
        self.suite = suite
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        suite.yield(.statut((response as? HTTPURLResponse)?.statusCode ?? -1))
        completionHandler(.allow)
    }

    public func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data
    ) {
        suite.yield(.octets(data))
    }

    public func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
    ) {
        suite.yield(.fin(error.map { $0.localizedDescription }))
        suite.finish()
    }
}
