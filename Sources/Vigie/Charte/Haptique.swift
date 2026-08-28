// Le retour haptique de la charte — alias vers le mappage unique du socle
// `Systeme` (`Toucher`). Les noms historiques restent : `Haptique.garde` est
// la butée du socle. Un geste = un retour, jamais deux.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Haptique {
    /// Appui sur un contrôle — léger, presque subliminal.
    public static let contact = Toucher.contact
    /// Bascule, onglet, choix dans une liste.
    public static let selection = Toucher.selection
    /// Un geste serveur a abouti.
    public static let reussite = Toucher.reussite
    /// Armement d'un geste irréversible, franchissement d'un seuil.
    public static let garde = Toucher.butee
    /// La file du quart grossit : quelque chose attend désormais.
    public static let alerte = Toucher.alerte
    /// Maintien abouti d'un `BoutonArme`.
    public static let engagement = Toucher.engagement
}
#endif
