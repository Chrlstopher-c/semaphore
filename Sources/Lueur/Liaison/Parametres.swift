// Adresse du serveur Lueur du Pi, injectée dans l'Info.plist par build.sh depuis .env.local (ECHO_ADRESSE_LUEUR).
#if canImport(UIKit)
import Foundation

enum Parametres {
    static var base: URL? {
        guard let brut = Bundle.main.object(forInfoDictionaryKey: "EchoAdresseLueur") as? String else { return nil }
        let adresse = brut.trimmingCharacters(in: .whitespaces)
        return adresse.isEmpty ? nil : URL(string: adresse)
    }
}
#endif
