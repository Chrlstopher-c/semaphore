// Le seul jeton de couleur propre à Tamis : son accent. Tout le reste — fonds,
// encres, traits, états — vient du socle `Systeme`.
//
// `☠` L'accent ne doit être cousin d'aucun autre monde : terracotta `#D97757`
// (Vigie), pervenche `#8A7AFF` (EchoHub), turquoise `#2AD4C6` (Saily),
// framboise `#F2589B` (Duplex). Reste le citron : jaune-vert franc, loin du vert
// `ok` `#5CB97C` par sa luminance, loin de l'ambre `alerte` par sa teinte.
//
// `☠` Deux couleurs se partagent le monde et ne se mélangent jamais : l'accent
// dit « on garde / on agit », le rouge `panne` du socle dit « ça part ». Un tri
// se lit à ces deux couleurs seules.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Teinte {
    /// Citron — l'interactif, et ce qu'on garde.
    public static let accent = Color(socle: 0xCADB4E)
    public static let accentPresse = Color(socle: 0xCADB4E).mele(vers: .black, part: 0.22)
    /// L'encre sur un aplat d'accent : le blanc n'y tient pas (1,4:1).
    public static let encreSurAccent = Neutre.fond
    /// Ce qui part. Alias du rouge du socle, nommé pour le tri : un écran de Tamis
    /// ne parle jamais de « panne ».
    public static let depart = Semantique.panne
}
#endif
