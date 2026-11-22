// Le jeton d'appareil dans le trousseau iOS. Mesuré le 17/08 : le trousseau survit à une réinstallation par-dessus
// (même bundle), donc la connexion aussi.
#if canImport(SwiftUI)
import Foundation
import Security
import VigieNoyau

enum Trousseau {
    private static let service = "com.echo.labs.vigie"
    static let compteCle = "cle-noeud-quart" // l'ancien « jeton-relais » de Vigie n'est plus lu

    /// Identité de l'appareil (graines X25519/Ed25519, JSON) et état du lien par l'aiguilleur (JSON).
    static let compteIdentite = "identite-appareil-quart"
    static let compteAiguilleur = "aiguilleur-quart"

    static func lire(compte: String = compteCle) -> String? {
        let requete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: compte, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var resultat: AnyObject?
        guard SecItemCopyMatching(requete as CFDictionary, &resultat) == errSecSuccess,
              let donnees = resultat as? Data else { return nil }
        return String(data: donnees, encoding: .utf8)
    }

    static func ecrire(_ jeton: String?, compte: String = compteCle) {
        let cle: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: compte,
        ]
        SecItemDelete(cle as CFDictionary)
        guard let jeton else { return }
        var ajout = cle
        ajout[kSecValueData as String] = Data(jeton.utf8)
        // Lisible après le premier déverrouillage : un réveil de fond écran verrouillé doit pouvoir sonder le relais.
        ajout[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let statut = SecItemAdd(ajout as CFDictionary, nil)
        if statut != errSecSuccess { Trace.erreur("lien", "jeton non enregistré dans le trousseau (\(statut))") }
    }
}
#endif
