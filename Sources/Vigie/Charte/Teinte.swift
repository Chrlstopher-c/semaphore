// Les couleurs de « Quart de nuit » — les neutres et les sémantiques viennent
// du socle `Systeme` ; Vigie n'y ajoute que son accent terracotta et les jetons
// sans équivalent socle. Les noms historiques sont conservés : les composants
// écrivent `Teinte.fond` sans savoir que la valeur vit ailleurs.
//
// `☠` Aucune couleur nue dans un écran : tout passe par ces jetons ou par
// `Ton`. Une couleur locale est le début de la pourriture d'une charte.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Teinte {

    // MARK: - Fonds — socle

    public static let fond = Neutre.fond
    /// Zones en retrait : rails, encarts creusés, fond du composeur. Pas
    /// d'équivalent socle (le socle n'a pas de fond « creusé ») — gardé local,
    /// accordé aux neutres chauds du socle.
    public static let fondCreux = Color(socle: 0x100D0A)
    public static let surface = Neutre.surface
    public static let surfaceHaute = Neutre.surfaceHaute

    // MARK: - Traits — socle

    public static let filet = Neutre.trait
    public static let filetAppuye = Neutre.lumiereHaute

    // MARK: - Encres — socle

    public static let encre = Neutre.encre
    public static let encreDouce = Neutre.encreDouce
    public static let encreTernie = Neutre.encreEteinte

    // MARK: - Accent — le SEUL jeton couleur propre à Vigie

    /// Badlands. `☠` Réservé à « ta main est requise » — jamais décoratif.
    public static let accent = Color(socle: 0xD97757)
    public static let accentPresse = Color(socle: 0xC0603E)
    /// Encre posée sur un fond accent : sombre, contraste 5,6:1. Le blanc n'y
    /// atteint que 3:1 — illisible en petit corps.
    public static let encreSurAccent = Color(socle: 0x2B130A)

    // MARK: - Sémantiques — socle

    public static let sain = Semantique.ok
    public static let vigilance = Semantique.alerte
    public static let danger = Semantique.panne
    /// Le calme : PC éteint, pause, repos. Jamais peint en rouge. Pas d'état
    /// « veille » dans le socle — gardé local.
    public static let veille = Color(socle: 0x92A7BD)

    // MARK: - Terminal — propre à Vigie, pas d'équivalent socle

    public static let terminalFond = Color(socle: 0x0D0B09)
    public static let terminalTexte = Color(socle: 0xE3DCD2)
}
#endif
