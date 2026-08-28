// Les voix de « La Besace ». L'échelle est celle d'Apple ; ce qui est propre au
// monde, c'est le choix du DESSIN ARRONDI (`.rounded`) pour tout ce qui
// s'adresse à Chris — titres, libellés, corps de note.
//
// `☠` Chaque voix est bâtie sur un TEXT STYLE SYSTÈME (`.title`, `.body`,
// `.footnote`…), jamais sur une taille en dur : c'est ce qui fait grossir toute
// l'app avec les réglages d'accessibilité (Dynamic Type). Une taille figée
// (`size: 16`) ignore ces réglages — c'est le défaut que cette charte bannit.
//
// `☠` La signature qui distingue Saily des deux autres mondes SANS embarquer une
// seule police : EchoHub compose en SF Pro neutre, Saily en SF Pro Rounded. Le
// rond dit « personnel, léger », là où le neutre dit « machine ». Le monospace
// (URLs, noms de blob, compteurs) reste chasse fixe : un chiffre qui danse est
// insupportable.
#if canImport(SwiftUI)
import SwiftUI

public enum Typo {
    // MARK: - Ce qui s'adresse à Chris (SF Pro Rounded, Dynamic Type)

    /// Titre d'écran. Bâti sur `.title` : franc, mais il grossit avec le réglage
    /// d'accessibilité comme le reste.
    public static let titreEcran = Font.system(.title, design: .rounded, weight: .bold)
    public static let titreSection = Font.system(.title3, design: .rounded, weight: .semibold)
    /// Le corps d'une note : le texte qu'on relit dans l'inbox.
    public static let corps = Font.system(.body, design: .rounded)
    public static let entete = Font.system(.body, design: .rounded, weight: .semibold)
    public static let mention = Font.system(.subheadline, design: .rounded, weight: .medium)
    public static let note = Font.system(.footnote, design: .rounded)
    public static let legende = Font.system(.caption, design: .rounded, weight: .medium)

    // MARK: - Ce qui vient d'une machine (SF Mono, Dynamic Type)

    /// Un lien affiché tel quel, un nom de blob : chasse fixe, parce que c'est de
    /// la donnée brute et qu'elle se lit comme telle. Bâti sur `.footnote` pour
    /// suivre Dynamic Type malgré le dessin monospacé.
    public static let brut = Font.system(.footnote, design: .monospaced)

    // MARK: - Mesures

    /// Compteurs (nombre d'items, taille), horodatage relatif : chiffres à
    /// chasse fixe pour que la largeur ne tremble pas, mais taille relative.
    public static let mesure = Font.system(.caption, design: .rounded).monospacedDigit()

    // MARK: - Interlignes de lecture

    /// L'interligne ajouté au corps d'une note : le régime d'une note qu'on
    /// relit, pas d'un libellé. Valeur typographique, HORS de la grille `Trame`.
    public static let interligneNote: CGFloat = 3
}

extension View {
    public func titreEcran() -> some View { font(Typo.titreEcran) }
    public func titreSection() -> some View { font(Typo.titreSection) }
    public func corps() -> some View { font(Typo.corps) }
    public func entete() -> some View { font(Typo.entete) }
    public func mention() -> some View { font(Typo.mention) }
    public func note() -> some View { font(Typo.note) }
    public func legende() -> some View { font(Typo.legende) }
    public func brut() -> some View { font(Typo.brut) }
    public func mesure() -> some View { font(Typo.mesure) }

    /// Tête de rubrique : capitales espacées, éteintes. La section s'annonce à
    /// voix basse — c'est le contenu qui parle.
    public func rubrique() -> some View {
        font(Typo.legende)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Teinte.encreDouce)
    }
}
#endif
