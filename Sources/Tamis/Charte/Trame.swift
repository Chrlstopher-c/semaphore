// Les dimensions propres au monde — des tailles de composant, pas des
// espacements : la grille de 4 pt gouverne les distances.
#if canImport(SwiftUI)
import CoreGraphics

public enum Trame {
    /// L'épaisseur d'une strate annuelle : assez pour se toucher, assez fine
    /// pour que quinze années tiennent sur un écran.
    public static let strate: CGFloat = 12
    /// Celle d'une strate mensuelle, dépliée sous son année.
    public static let strateMois: CGFloat = 6
    /// Colonnes de la grille de vignettes : 4 sur 335 pt, soit ~80 pt, le
    /// plancher où une photo se reconnaît encore.
    public static let colonnes = 4
    /// L'écart entre vignettes : un filet, pas une marge.
    public static let jointure: CGFloat = 4
    /// La carte du tri rapide, en proportion de la largeur utile.
    public static let carteTri: CGFloat = 1.3
    /// Distance de glisse qui vaut décision.
    public static let seuilGlisse: CGFloat = 110
    /// Où s'envole une carte jugée : au-delà du bord de l'écran.
    public static let envol: CGFloat = 480
    /// Les trois boutons ronds du tri : au-dessus de la cible, on les frappe vite.
    public static let bouton: CGFloat = 64
    /// Une vignette dans une rangée de groupe : plus grande que la grille, on y
    /// compare des quasi-jumelles.
    public static let vignetteGroupe: CGFloat = 112
    /// Le cadre de l'élue.
    public static let traitElue: CGFloat = 3
    /// Poids plancher d'une strate dessinée : une année minuscule reste visible.
    public static let largeurMin: CGFloat = 0.02
    /// La colonne des noms de mois : « septembre » en note tient en 72 pt.
    public static let libelleMois: CGFloat = 72
    /// Le côté de l'aperçu d'appui long.
    public static let apercu: CGFloat = 320
}
#endif
