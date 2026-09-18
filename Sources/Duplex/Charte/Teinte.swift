// Le seul jeton de couleur propre à Duplex : son accent. Tout le reste — fonds,
// encres, traits, états — vient du socle `Systeme`, comme dans les autres mondes,
// et les écrans l'écrivent directement (`Neutre`, `Semantique`) : aucun alias
// local, un jeton sans emploi propre n'existe pas.
//
// `☠` L'accent vit sur UNE seule chose par écran : le geste à faire (l'anneau
// au repos, le bouton Valider) ou le son qui coule (l'anneau en écoute). Un
// écran où deux éléments portent la framboise n'en désigne plus aucun.
//
// `☠` L'accent ne doit être cousin d'aucun autre monde : la barre du pupitre les
// montre côte à côte, et deux accents voisins s'y lisent comme une incohérence,
// pas comme une identité. Les trois déjà pris : terracotta `#D97757` (Vigie),
// pervenche `#8A7AFF` (EchoHub), turquoise `#2AD4C6` (Saily). Le rose framboise
// est le seul creux de teinte qui reste — et il se distingue du rouge `panne`
// `#E05B49` par sa saturation autant que par sa teinte.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Teinte {
    /// Rose framboise — dit « ceci est interactif » et « le son coule ».
    public static let accent = Color(socle: 0xF2589B)
    /// L'accent enfoncé. Dérivé, jamais saisi à la main : deux teintes cousines
    /// écrites séparément divergent à la première retouche.
    public static let accentPresse = Color(socle: 0xF2589B).mele(vers: .black, part: 0.22)
    /// L'encre posée sur un aplat d'accent : le fond de page, sombre. Le blanc
    /// n'atteint que 3:1 sur cette framboise — illisible en petit corps.
    public static let encreSurAccent = Neutre.fond
}
#endif
