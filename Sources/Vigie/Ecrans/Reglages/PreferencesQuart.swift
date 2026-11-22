// Les préférences de Quart gardées sur l'iPhone : réglages par défaut des nouvelles sessions.
#if canImport(SwiftUI)
import Foundation

enum PreferencesQuart {
    private static let cleModele = "quart.defaut.modele"
    private static let cleEffort = "quart.defaut.effort"
    private static let cleMode = "quart.defaut.mode"

    static var modeleParDefaut: String {
        get { UserDefaults.standard.string(forKey: cleModele) ?? "claude-opus-5-5" }
        set { UserDefaults.standard.set(newValue, forKey: cleModele) }
    }

    /// nil = effort par défaut du modèle.
    static var effortParDefaut: String? {
        get { UserDefaults.standard.string(forKey: cleEffort) }
        set { UserDefaults.standard.set(newValue, forKey: cleEffort) }
    }

    /// nil = mode par défaut du nœud (tout autoriser).
    static var modeParDefaut: String? {
        get { UserDefaults.standard.string(forKey: cleMode) }
        set { UserDefaults.standard.set(newValue, forKey: cleMode) }
    }
}
#endif
