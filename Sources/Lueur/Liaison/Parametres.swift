// Adresse et clé d'appareil du serveur Lueur du Pi, injectées dans l'Info.plist par build.sh
// depuis .env.local (ECHO_ADRESSE_LUEUR, ECHO_CLE_LUEUR).
#if canImport(UIKit)
import Foundation

enum Parametres {
    static var base: URL? {
        guard let brut = Bundle.main.object(forInfoDictionaryKey: "EchoAdresseLueur") as? String else { return nil }
        let adresse = brut.trimmingCharacters(in: .whitespaces)
        return adresse.isEmpty ? nil : URL(string: adresse)
    }

    static var cle: String? {
        let info = Bundle.main.object(forInfoDictionaryKey: "EchoCleLueur") as? String
        let brute = info?.trimmingCharacters(in: .whitespaces)
        return brute?.isEmpty == false ? brute : nil
    }
}
#endif
