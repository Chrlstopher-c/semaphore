// Adresse du relais et clé partagée, injectées dans l'Info.plist par build.sh depuis .env.local.
#if canImport(UIKit)
import Foundation

enum Parametres {
    static var cle: String {
        (Bundle.main.object(forInfoDictionaryKey: "EchoCleIris") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// `nil` sans clé ou sans adresse (ECHO_ADRESSE_IRIS) : rien à joindre.
    static var urlRelais: URL? {
        let cle = self.cle
        guard cle.count >= 16 else { return nil }
        guard let base = Bundle.main.object(forInfoDictionaryKey: "EchoAdresseIris") as? String,
              !base.isEmpty else { return nil }
        var composants = URLComponents(string: base)
        composants?.queryItems = [URLQueryItem(name: "role", value: "camera"), URLQueryItem(name: "cle", value: cle)]
        return composants?.url
    }
}
#endif
