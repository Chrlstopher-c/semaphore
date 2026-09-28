// Adresse du relais et clé partagée, injectées dans l'Info.plist par build.sh depuis .env.local.
#if canImport(UIKit)
import Foundation

enum Parametres {
    static let relaisParDefaut = "wss://iris.christophercouspeyre.com/ws"

    static var cle: String {
        (Bundle.main.object(forInfoDictionaryKey: "EchoCleIris") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// `nil` sans clé : le relais refuserait la connexion, inutile d'essayer.
    static var urlRelais: URL? {
        let cle = self.cle
        guard cle.count >= 16 else { return nil }
        let base = (Bundle.main.object(forInfoDictionaryKey: "EchoAdresseIris") as? String)
            .flatMap { $0.isEmpty ? nil : $0 } ?? relaisParDefaut
        var composants = URLComponents(string: base)
        composants?.queryItems = [URLQueryItem(name: "role", value: "camera"), URLQueryItem(name: "cle", value: cle)]
        return composants?.url
    }
}
#endif
