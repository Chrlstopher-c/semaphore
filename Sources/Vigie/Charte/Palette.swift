// La charte Echo Agency (skill echo-agency-design), en deux thèmes : clair (canvas sable, accent brand-600) et night
// (#1E1830, accent brand-400). Vigie suit le mode de l'iPhone. Écart déclaré au skill ios-design : pas de noir OLED,
// la charte du projet prime (le night est un violet profond, pas un noir).
#if canImport(SwiftUI)
import SwiftUI

extension Color {
    init(hex: UInt32, opacite: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacite)
    }
}

public struct Palette: Sendable {
    let fond: Color // fond de page
    let surface: Color // cartes, cellules
    let surface2: Color // posé sur une surface (champ, piste de jauge)
    let encre: Color // titres et corps
    let encreDouce: Color // texte secondaire
    let discret: Color // métadonnées, placeholders
    let filet: Color // séparateurs, liseré des cartes
    let accent: Color // l'action : boutons pleins, bascules actives
    let accentVif: Color // points, barres, pastilles
    let accentTexte: Color // texte accentué, surtitres
    let accentFond: Color // fond de tag, état choisi
    let relief: Color // relief du bouton plein
    let succes: Color
    let danger: Color
    let alerte: Color

    static let clair = Palette(
        fond: Color(hex: 0xFAFAF9), surface: .white, surface2: Color(hex: 0xF2EFE9), encre: Color(hex: 0x141414),
        encreDouce: Color(hex: 0x3F3C39), discret: Color(hex: 0x6B6660), filet: Color(hex: 0xEAE7E1),
        accent: Color(hex: 0x7D48B5), accentVif: Color(hex: 0xA774D4), accentTexte: Color(hex: 0x5E3290),
        accentFond: Color(hex: 0xF4EDFB), relief: Color(hex: 0x56298A), succes: Color(hex: 0x0B7A52),
        danger: Color(hex: 0xB42318), alerte: Color(hex: 0x7A4800))

    static let night = Palette(
        fond: Color(hex: 0x1E1830), surface: Color(hex: 0x251E38), surface2: Color(hex: 0x2E2644),
        encre: Color(hex: 0xF3F1F6), encreDouce: Color(hex: 0xC8C4D0), discret: Color(hex: 0xA39DB5),
        filet: Color(hex: 0x362D4D), accent: Color(hex: 0xA774D4), accentVif: Color(hex: 0xD5B8F0),
        accentTexte: Color(hex: 0xD5B8F0), accentFond: Color(hex: 0xA774D4, opacite: 0.18), relief: Color(hex: 0x5E3290),
        succes: Color(hex: 0x5FD3A3), danger: Color(hex: 0xF2B8B0), alerte: Color(hex: 0xFFD99A))

    static func pour(_ schema: ColorScheme) -> Palette { schema == .dark ? .night : .clair }
}

private struct ClePalette: EnvironmentKey {
    static let defaultValue = Palette.night
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[ClePalette.self] }
        set { self[ClePalette.self] = newValue }
    }
}

/// L'accent de Vigie vu par le pupitre (chrome sombre) : brand-400.
public enum Teinte {
    public static let accent = Color(hex: 0xA774D4)
}

/// Grille 4 pt (skill ios-design) et rayons de la charte, adaptés au téléphone.
enum Espace {
    static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, marge: CGFloat = 20, xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Rayon {
    static let controle: CGFloat = 12
    static let carte: CGFloat = 20 // 24 sur le bureau ; 20 sur 375 pt pour garder de la surface utile
    static let feuille: CGFloat = 28
}

enum Mouvement {
    static let micro = Animation.snappy(duration: 0.2)
    static let standard = Animation.spring(duration: 0.35, bounce: 0.12)
    static let surface = Animation.smooth(duration: 0.45)
}
#endif
