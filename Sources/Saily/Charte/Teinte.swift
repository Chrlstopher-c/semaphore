// Les couleurs de « La Besace ». Sombre permanent, neutres graphite LÉGÈREMENT
// CHAUDS — le contraire du froid d'EchoHub, pour qu'on sente d'un coup d'œil
// qu'on a changé de monde — et un seul accent : un turquoise vif.
//
// `☠` Aucune couleur nue dans un écran : tout passe par ces jetons, par `Ton`
// ou par l'`Ambiance`. Chaque jeton porte son emploi ; sans emploi écrit, il ne
// doit pas exister. C'est la règle qui empêche une charte de pourrir.
//
// `☠` L'accent turquoise `#2AD4C6` n'est NI la pervenche `#8A7AFF` d'EchoHub NI
// le bleu de Vigie : les trois mondes cohabitent dans un seul bundle, et deux
// accents voisins se liraient comme une incohérence, pas comme une identité.
#if canImport(SwiftUI)
import SwiftUI

public enum Teinte {

    // MARK: - Fonds — graphite chaud, sombre permanent

    /// La page. Un noir chaud, pas noir pur : le noir vrai laisse une traînée au
    /// défilement sur OLED, et une inbox défile beaucoup.
    public static let fond = Color(besace: 0x0E0D0C)
    /// Cartes d'item, rangées, champs.
    public static let surface = Color(besace: 0x1A1815)
    /// Ce qui est posé SUR une surface : composeur de capture, feuille.
    public static let surfaceHaute = Color(besace: 0x232019)

    // MARK: - Traits et lumière

    public static let trait = Color.white.opacity(0.09)
    /// Haut du liseré directionnel — la lumière vient toujours du haut.
    public static let lumiereHaute = Color.white.opacity(0.13)
    /// Bas du même liseré. C'est l'écart qui fait le volume ; sur fond sombre,
    /// une ombre ne se voit pas.
    public static let lumiereBasse = Color.white.opacity(0.04)

    // MARK: - Encres — une par rôle, et pas une de plus

    /// Le texte d'une note, les titres. Blanc cassé CHAUD, accordé au graphite.
    public static let encre = Color(besace: 0xF2EEE7)
    /// Le secondaire : légendes, méta, tags au repos, horodatage.
    public static let encreDouce = Color(besace: 0xA39C8E)
    /// L'éteint : placeholders, désactivé, glyphes d'état vide.
    public static let encreEteinte = Color(besace: 0x6C6459)

    // MARK: - Accent

    /// Turquoise — la seule teinte propre du monde. Elle dit deux choses et rien
    /// d'autre : « ceci est interactif » et « la synchro est vivante ».
    public static let accent = Color(besace: 0x2AD4C6)
    /// L'accent enfoncé. Dérivé, jamais saisi à la main : deux teintes cousines
    /// écrites séparément divergent à la première retouche.
    ///
    /// Le voile d'un accent (fond de pastille) n'a PAS de jeton ici : il
    /// s'obtient par `Ton.actif.voile`, l'unique porte des fonds voilés.
    public static let accentPresse = Color(besace: 0x2AD4C6).mix(with: .black, by: 0.22)

    // MARK: - États

    /// Item synchronisé, serveur joignable. Vert JAUNE, écarté du turquoise pour
    /// qu'un état « ok » ne se confonde pas avec l'accent.
    public static let ok = Color(besace: 0x8CC96B)
    /// Récupérable : hors ligne, capture en attente de rejeu, téléversement lent.
    public static let alerte = Color(besace: 0xE3B34E)
    /// Échec réel et geste destructif — supprimer un item. Le seul rouge.
    public static let panne = Color(besace: 0xE5644E)
}

extension Color {
    /// `Color(besace: 0x2AD4C6)` — sRGB, opaque.
    init(besace hexa: UInt32) {
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
