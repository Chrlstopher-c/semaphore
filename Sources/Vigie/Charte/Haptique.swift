// Le retour haptique de la charte, calibré par nature d'événement.
// Un geste = un retour, jamais deux. Tout passe par `sensoryFeedback`.
#if canImport(SwiftUI)
import SwiftUI

public enum Haptique {
    /// Appui sur un contrôle — léger, presque subliminal.
    public static let contact = SensoryFeedback.impact(weight: .light, intensity: 0.7)
    /// Bascule, onglet, choix dans une liste.
    public static let selection = SensoryFeedback.selection
    /// Un geste serveur a abouti.
    public static let reussite = SensoryFeedback.success
    /// Armement d'un geste irréversible, franchissement d'un seuil.
    public static let garde = SensoryFeedback.warning
    /// La file du quart grossit : quelque chose attend désormais.
    public static let alerte = SensoryFeedback.error
    /// Maintien abouti d'un `BoutonArme`.
    public static let engagement = SensoryFeedback.impact(weight: .heavy, intensity: 1)
}
#endif
