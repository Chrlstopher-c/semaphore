// Les couleurs de « Quart de nuit » — sombre unique, neutres chauds, orange
// réservé à ce qui réclame la main de Chris. Voir CHARTE.md pour les règles.
//
// `☠` Aucune couleur nue dans un écran : tout passe par ces jetons ou par
// `Ton`. Une couleur locale est le début de la pourriture d'une charte.
#if canImport(SwiftUI)
import SwiftUI

public enum Teinte {

    // MARK: - Fonds

    public static let fond = Color(quart: 0x171210)
    /// Zones en retrait : rails, encarts creusés, fond du composeur.
    public static let fondCreux = Color(quart: 0x100D0A)
    public static let surface = Color(quart: 0x201A15)
    /// Feuilles, bulles, éléments soulevés au-dessus d'un panneau.
    public static let surfaceHaute = Color(quart: 0x2B231C)

    // MARK: - Traits

    public static let filet = Color.white.opacity(0.07)
    public static let filetAppuye = Color.white.opacity(0.14)

    // MARK: - Encres

    public static let encre = Color(quart: 0xF2EAE3)
    public static let encreDouce = Color(quart: 0xB9ACA0)
    public static let encreTernie = Color(quart: 0x8A7D71)

    // MARK: - Accent

    /// Badlands. `☠` Réservé à « ta main est requise » — jamais décoratif.
    public static let accent = Color(quart: 0xD97757)
    public static let accentPresse = Color(quart: 0xC0603E)
    /// Encre posée sur un fond accent : sombre, contraste 5,6:1. Le blanc n'y
    /// atteint que 3:1 — illisible en petit corps.
    public static let encreSurAccent = Color(quart: 0x2B130A)

    // MARK: - Sémantiques

    public static let sain = Color(quart: 0x8FBE7C)
    public static let vigilance = Color(quart: 0xE3AE4F)
    /// Framboise franc, volontairement éloigné de l'orange accent : les deux
    /// cohabitent sur une carte de mandat en écriture.
    public static let danger = Color(quart: 0xE6404D)
    /// Le calme : PC éteint, pause, repos. Jamais peint en rouge.
    public static let veille = Color(quart: 0x92A7BD)

    // MARK: - Terminal

    public static let terminalFond = Color(quart: 0x0D0B09)
    public static let terminalTexte = Color(quart: 0xE3DCD2)
}

extension Color {
    /// `Color(quart: 0xD97757)` — sRGB, opaque.
    init(quart hexa: UInt32) {
        self.init(
            .sRGB,
            red: Double((hexa >> 16) & 0xFF) / 255,
            green: Double((hexa >> 8) & 0xFF) / 255,
            blue: Double(hexa & 0xFF) / 255,
            opacity: 1
        )
    }
}
#endif
