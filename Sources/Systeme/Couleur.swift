// Le socle chromatique commun aux trois mondes. UNE seule vérité pour les
// neutres et les états ; chaque monde n'ajoute par-dessus qu'UNE couleur, son
// accent. C'est le principe du système : la structure fait la famille, la
// couleur fait l'identité.
//
// `☠` Aucun monde ne redéfinit un neutre ni une sémantique. Un fond qui diverge
// d'un monde à l'autre, c'est l'incohérence qu'on vient justement de tuer. Le
// SEUL jeton propre à un monde est `accent`, défini dans son `Teinte` local.
//
// Neutres graphite CHAUDS (teintés vers l'ambre, pas gris pur : un gris nu se lit
// comme non choisi), sombres permanents. Sémantiques tirées vers le chaud pour
// tenir sur ce graphite sans détonner.
#if canImport(SwiftUI)
import SwiftUI

/// Les fonds, les encres, les lumières. Identiques partout.
public enum Neutre {

    // MARK: - Fonds — graphite chaud, sombre permanent

    /// La page. Un noir chaud, pas noir pur : le noir vrai laisse une traînée au
    /// défilement sur OLED.
    public static let fond = Color(socle: 0x141210)
    /// Cartes, panneaux, listes, rangées.
    public static let surface = Color(socle: 0x1C1917)
    /// Ce qui est posé SUR une surface : feuilles, champs actifs, survols.
    public static let surfaceHaute = Color(socle: 0x242018)

    // MARK: - Traits et lumière — l'ombre ne se voit pas sur fond sombre

    /// Séparateurs de liste, filet discret.
    public static let trait = Color.white.opacity(0.11)
    /// Haut du liseré directionnel — la lumière vient toujours du haut.
    public static let lumiereHaute = Color.white.opacity(0.13)
    /// Bas du même liseré. C'est l'écart qui fait le volume.
    public static let lumiereBasse = Color.white.opacity(0.04)

    // MARK: - Encres — une par rôle, et pas une de plus

    /// Titres, corps de texte. Blanc cassé CHAUD, accordé au graphite.
    public static let encre = Color(socle: 0xEDE6DB)
    /// Le secondaire : descriptions, mentions, méta.
    public static let encreDouce = Color(socle: 0xB9B0A3)
    /// L'éteint : placeholders, désactivé, glyphes d'état vide, légendes.
    public static let encreEteinte = Color(socle: 0x7E7669)
}

/// Les états système. Un « ok » a la même couleur dans les trois mondes —
/// l'accent d'un monde ne s'y mélange jamais.
public enum Semantique {
    /// Service en ligne, tâche réussie, item synchronisé.
    public static let ok = Color(socle: 0x5CB97C)
    /// Dégradation, seuil approché, hors ligne récupérable.
    public static let alerte = Color(socle: 0xDFA349)
    /// Service tombé, échec réel, geste destructif. Le seul rouge.
    public static let panne = Color(socle: 0xE05B49)
}

extension Color {
    /// `Color(socle: 0x141210)` — sRGB, opaque. L'unique fabrique de couleur du
    /// système ; les mondes s'en servent aussi pour leur accent.
    public init(socle hexa: UInt32) {
        self.init(
            .sRGB,
            red: Double((hexa >> 16) & 0xFF) / 255,
            green: Double((hexa >> 8) & 0xFF) / 255,
            blue: Double(hexa & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Mélange linéaire vers une autre couleur — pour dériver un accent enfoncé
    /// sans le saisir à la main (deux teintes cousines écrites séparément
    /// divergent à la première retouche).
    public func mele(vers autre: Color, part: Double) -> Color {
        let bornee = min(max(part, 0), 1)
        return Color(
            .sRGB,
            red: composante(.rouge) * (1 - bornee) + autre.composante(.rouge) * bornee,
            green: composante(.vert) * (1 - bornee) + autre.composante(.vert) * bornee,
            blue: composante(.bleu) * (1 - bornee) + autre.composante(.bleu) * bornee,
            opacity: 1
        )
    }

    private enum Canal { case rouge, vert, bleu }

    private func composante(_ canal: Canal) -> Double {
        #if canImport(UIKit)
        var r: CGFloat = 0, v: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &v, blue: &b, alpha: &a)
        switch canal {
        case .rouge: return Double(r)
        case .vert: return Double(v)
        case .bleu: return Double(b)
        }
        #else
        return 0
        #endif
    }
}
#endif
