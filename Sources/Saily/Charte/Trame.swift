// La trame : la grille de 4 pt et les galbes viennent du socle `Systeme`
// (`Grille`, `Rayon`). Toute valeur de `padding` ou de `spacing` du monde
// appartient à cette liste — sous 4 pt il n'y a rien, 2, 3, 5 et 6 n'existent
// pas. Restent locales les hauteurs propres à l'inbox : rangée, composeur,
// vignette — elles n'ont pas d'équivalent socle.
#if canImport(SwiftUI)
import CoreGraphics
import Systeme

public enum Trame {
    /// 4 — deux lignes d'un même bloc de texte.
    public static let fin = Grille.fin
    /// 8 — éléments liés d'une même rangée (glyphe et libellé, tags voisins).
    public static let serre = Grille.serre
    /// 12 — blocs internes d'une carte d'item.
    public static let element = Grille.element
    /// 16 — marge intérieure d'une carte.
    public static let bloc = Grille.bloc
    /// 20 — marge horizontale d'écran.
    public static let ecran = Grille.ecran
    /// 24 — entre deux items d'une liste aérée.
    public static let groupe = Grille.groupe
    /// 32 — entre deux sections.
    public static let section = Grille.section
    /// 48 — respiration d'un état calme.
    public static let souffle = Grille.souffle

    public static let trait = Grille.trait
    /// Plancher d'une zone tapable, glyphe compris.
    public static let cible = Grille.cible

    // MARK: - Hauteurs propres au monde — pas d'équivalent socle

    /// Hauteur d'une rangée d'item confortable dans la vue liste.
    public static let rangee: CGFloat = 64
    /// Hauteur du composeur de capture au repos, avant qu'il ne grandisse.
    public static let composeur: CGFloat = 52
    /// Côté d'une vignette d'aperçu (image/vidéo) dans une rangée d'item.
    public static let vignette: CGFloat = 56
}

/// Galbes continus — les coins circulaires trahissent l'amateur. Les valeurs
/// sont celles du socle `Rayon` (carte 16, feuille 24 — Saily abandonne ses
/// 18/26 historiques au profit de la cohérence). Deux arrondis imbriqués
/// gardent au moins 8 pt d'écart, sinon ils se contredisent.
public enum Galbe {
    /// Contrôles, pastilles, tags, vignettes.
    public static let controle = Rayon.controle
    /// Cartes d'item, blocs.
    public static let carte = Rayon.carte
    /// Feuilles présentées par-dessus.
    public static let feuille = Rayon.feuille
}
#endif
