// La trame : grille de 4 pt, galbes continus, cibles tactiles. Toute valeur de
// `padding` ou de `spacing` de l'app appartient à cette liste — sous 4 pt il
// n'y a rien, 2, 3, 5 et 6 n'existent pas.
#if canImport(SwiftUI)
import CoreGraphics

public enum Trame {
    /// 4 — deux lignes d'un même bloc de texte.
    public static let fin: CGFloat = 4
    /// 8 — éléments liés d'une même rangée.
    public static let serre: CGFloat = 8
    /// 12 — blocs internes d'une carte.
    public static let element: CGFloat = 12
    /// 16 — marge intérieure d'une carte, glyphe et libellé qu'il annonce.
    public static let bloc: CGFloat = 16
    /// 20 — marge horizontale d'écran (375 − 2 × 20 = 335 pt utiles).
    public static let ecran: CGFloat = 20
    /// 24 — entre deux tours de conversation.
    public static let groupe: CGFloat = 24
    /// 32 — entre deux sections.
    public static let section: CGFloat = 32
    /// 48 — respiration d'un état calme.
    public static let souffle: CGFloat = 48

    public static let trait: CGFloat = 1
    /// Plancher d'une zone tapable, glyphe compris.
    public static let cible: CGFloat = 44
    /// Hauteur d'une rangée de liste confortable.
    public static let rangee: CGFloat = 56
    /// Hauteur du composeur au repos, avant qu'il ne grandisse avec le texte.
    public static let composeur: CGFloat = 52
    /// Largeur maximale d'une bulle de Chris : 335 − 48. Une bulle qui prend
    /// toute la largeur ne se distingue plus de la réponse du modèle, qui elle
    /// n'a pas de bulle du tout.
    public static let bulleMax: CGFloat = 287
}

/// Galbes continus — les coins circulaires trahissent l'amateur. Deux arrondis
/// imbriqués gardent au moins 8 pt d'écart, sinon ils se contredisent.
public enum Galbe {
    /// Contrôles, pastilles, vignettes.
    public static let controle: CGFloat = 10
    /// Cartes, bulles, blocs repliés.
    public static let carte: CGFloat = 16
    /// Feuilles présentées par-dessus.
    public static let feuille: CGFloat = 24
}
#endif
