// La grille commune : espacements sur une base de 4 pt, galbes continus, cible
// tactile. UNE valeur de `padding` ou de `spacing` de toute l'app appartient à
// cette liste — sous 4 pt il n'y a rien, 2/3/5/6 n'existent pas. Une distance
// hors gamme est un bug de design, dans n'importe quel monde.
#if canImport(SwiftUI)
import CoreGraphics

public enum Grille {
    /// 4 — deux lignes d'un même bloc de texte.
    public static let fin: CGFloat = 4
    /// 8 — éléments liés d'une rangée (glyphe et libellé, tags voisins).
    public static let serre: CGFloat = 8
    /// 12 — blocs internes d'une carte.
    public static let element: CGFloat = 12
    /// 16 — marge intérieure d'une carte.
    public static let bloc: CGFloat = 16
    /// 20 — marge horizontale d'écran.
    public static let ecran: CGFloat = 20
    /// 24 — entre deux éléments d'une liste aérée.
    public static let groupe: CGFloat = 24
    /// 32 — entre deux sections.
    public static let section: CGFloat = 32
    /// 48 — respiration d'un état calme.
    public static let souffle: CGFloat = 48

    /// Épaisseur d'un filet.
    public static let trait: CGFloat = 1
    /// Plancher d'une zone tapable, glyphe compris. La règle Apple des 44 pt ne
    /// se lit pas sur le glyphe.
    public static let cible: CGFloat = 44
}

/// Galbes continus (`style: .continuous`) — les coins circulaires trahissent
/// l'amateur. Deux arrondis imbriqués gardent au moins 8 pt d'écart, sinon ils
/// se contredisent.
public enum Rayon {
    /// Contrôles, pastilles, tags, champs, vignettes.
    public static let controle: CGFloat = 10
    /// Cartes, panneaux, blocs.
    public static let carte: CGFloat = 16
    /// Feuilles présentées par-dessus.
    public static let feuille: CGFloat = 24
}
#endif
