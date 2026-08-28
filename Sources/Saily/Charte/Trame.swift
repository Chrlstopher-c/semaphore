// La trame : grille de 4 pt, galbes continus, cibles tactiles. Toute valeur de
// `padding` ou de `spacing` du monde appartient à cette liste — sous 4 pt il
// n'y a rien, 2, 3, 5 et 6 n'existent pas.
#if canImport(SwiftUI)
import CoreGraphics

public enum Trame {
    /// 4 — deux lignes d'un même bloc de texte.
    public static let fin: CGFloat = 4
    /// 8 — éléments liés d'une même rangée (glyphe et libellé, tags voisins).
    public static let serre: CGFloat = 8
    /// 12 — blocs internes d'une carte d'item.
    public static let element: CGFloat = 12
    /// 16 — marge intérieure d'une carte.
    public static let bloc: CGFloat = 16
    /// 20 — marge horizontale d'écran.
    public static let ecran: CGFloat = 20
    /// 24 — entre deux items d'une liste aérée.
    public static let groupe: CGFloat = 24
    /// 32 — entre deux sections.
    public static let section: CGFloat = 32
    /// 48 — respiration d'un état calme.
    public static let souffle: CGFloat = 48

    public static let trait: CGFloat = 1
    /// Plancher d'une zone tapable, glyphe compris.
    public static let cible: CGFloat = 44
    /// Hauteur d'une rangée d'item confortable dans la vue liste.
    public static let rangee: CGFloat = 64
    /// Hauteur du composeur de capture au repos, avant qu'il ne grandisse.
    public static let composeur: CGFloat = 52
    /// Côté d'une vignette d'aperçu (image/vidéo) dans une rangée d'item.
    public static let vignette: CGFloat = 56
}

/// Galbes continus — les coins circulaires trahissent l'amateur. Deux arrondis
/// imbriqués gardent au moins 8 pt d'écart, sinon ils se contredisent.
public enum Galbe {
    /// Contrôles, pastilles, tags, vignettes.
    public static let controle: CGFloat = 10
    /// Cartes d'item, blocs.
    public static let carte: CGFloat = 18
    /// Feuilles présentées par-dessus.
    public static let feuille: CGFloat = 26
}
#endif
