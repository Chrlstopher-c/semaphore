#if canImport(SwiftUI)
import Foundation
import VigieNoyau

/// `☠` LE DÉLÉGUÉ SANS LEQUEL RIEN NE MARCHE.
///
/// `check_session` (`pi-web/app.py:52-55`) répond **303 vers `/login`** dès que
/// le cookie de session manque ou ne correspond plus. `URLSession` suit les
/// redirections par défaut : le décodeur recevrait alors le **HTML de la page de
/// connexion, en 200**, et rendrait « contrat rompu » sur chaque route de
/// l'application — un symptôme qui ne pointe nulle part vers l'authentification.
///
/// En rendant `nil` au rappel, la redirection n'est pas suivie et le 302/303
/// remonte tel quel jusqu'à `ClientPi`, qui le traduit en « session à rouvrir ».
final class RefusRedirection: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

    /// `@unchecked Sendable` est ici exact et non un contournement : la classe
    /// n'a aucun état stocké, donc rien à protéger. Le marquage est nécessaire
    /// parce que `URLSession` retient son délégué depuis ses propres fils.

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        Trace.detail("lien", "redirection \(response.statusCode) refusée vers \(request.url?.path ?? "?")")
        completionHandler(nil)
    }
}
#endif
