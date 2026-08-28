// La trame : la grille du socle `Systeme` (base de 4 pt, galbes continus,
// cibles tactiles), plus les trois dimensions propres au « Fil ». Toute valeur
// de `padding` ou de `spacing` de l'app appartient à cette liste — sous 4 pt
// il n'y a rien, 2, 3, 5 et 6 n'existent pas.
#if canImport(SwiftUI)
import CoreGraphics
import Systeme

public enum Trame {
    /// 4 — deux lignes d'un même bloc de texte.
    public static let fin = Grille.fin
    /// 8 — éléments liés d'une même rangée.
    public static let serre = Grille.serre
    /// 12 — blocs internes d'une carte.
    public static let element = Grille.element
    /// 16 — marge intérieure d'une carte, glyphe et libellé qu'il annonce.
    public static let bloc = Grille.bloc
    /// 20 — marge horizontale d'écran (375 − 2 × 20 = 335 pt utiles).
    public static let ecran = Grille.ecran
    /// 24 — entre deux tours de conversation.
    public static let groupe = Grille.groupe
    /// 32 — entre deux sections.
    public static let section = Grille.section
    /// 48 — respiration d'un état calme.
    public static let souffle = Grille.souffle

    public static let trait = Grille.trait
    /// Plancher d'une zone tapable, glyphe compris.
    public static let cible = Grille.cible

    // MARK: - Dimensions propres à EchoHub, hors socle

    /// Hauteur d'une rangée de liste confortable.
    public static let rangee: CGFloat = 56
    /// Hauteur du composeur au repos, avant qu'il ne grandisse avec le texte.
    public static let composeur: CGFloat = 52
    /// Largeur maximale d'une bulle de Chris : 335 − 48. Une bulle qui prend
    /// toute la largeur ne se distingue plus de la réponse du modèle, qui elle
    /// n'a pas de bulle du tout.
    public static let bulleMax: CGFloat = 287
}

/// Galbes continus du socle — les coins circulaires trahissent l'amateur. Deux
/// arrondis imbriqués gardent au moins 8 pt d'écart, sinon ils se contredisent.
public enum Galbe {
    /// Contrôles, pastilles, vignettes.
    public static let controle = Rayon.controle
    /// Cartes, bulles, blocs repliés.
    public static let carte = Rayon.carte
    /// Feuilles présentées par-dessus.
    public static let feuille = Rayon.feuille
}
#endif
