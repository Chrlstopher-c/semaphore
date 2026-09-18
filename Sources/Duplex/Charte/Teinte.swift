// Le seul jeton de couleur propre à Duplex : son accent. Tout le reste — fonds,
// encres, traits, états — vient du socle `Systeme`, comme dans les autres mondes.
//
// La direction artistique de ce monde n'est PAS faite : les écrans sont
// volontairement sobres et n'utilisent que les jetons du socle. C'est ici que la
// charte se posera, et nulle part ailleurs dans `Sources/Duplex/`.
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
}
#endif
