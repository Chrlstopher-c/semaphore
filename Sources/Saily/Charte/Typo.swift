// Les voix de « La Besace ». L'échelle est celle d'Apple ; ce qui est propre au
// monde, c'est le choix du DESSIN ARRONDI (`.rounded`) pour tout ce qui
// s'adresse à Chris — titres, libellés, corps de note.
//
// `☠` C'est la signature typographique qui distingue Saily des deux autres
// mondes SANS embarquer une seule police : EchoHub compose en SF Pro neutre,
// Saily en SF Pro Rounded. Le rond dit « personnel, léger, où l'on jette des
// choses », là où le neutre dit « machine ». Dynamic Type reste intact, et l'IPA
// ne gagne pas un octet. Le monospace (compteurs, noms de blob) reste chasse
// fixe : un chiffre qui danse est insupportable.
#if canImport(SwiftUI)
import SwiftUI

public enum Typo {
    // MARK: - Ce qui s'adresse à Chris (SF Pro Rounded)

    /// Titre d'écran. 28 : la besace s'annonce franchement, elle n'a pas de
    /// « sujet » unique à ménager comme la réponse d'un modèle.
    public static let titreEcran = Font.system(size: 28, weight: .bold, design: .rounded)
    public static let titreSection = Font.system(size: 19, weight: .semibold, design: .rounded)
    /// Le corps d'une note : le texte qu'on relit dans l'inbox.
    public static let corps = Font.system(size: 16, design: .rounded)
    public static let entete = Font.system(size: 16, weight: .semibold, design: .rounded)
    public static let mention = Font.system(size: 15, weight: .medium, design: .rounded)
    public static let note = Font.system(size: 13, design: .rounded)
    public static let legende = Font.system(size: 12, weight: .medium, design: .rounded)

    // MARK: - Ce qui vient d'une machine (SF Mono)

    /// Un lien affiché tel quel, un nom de blob, une URL : chasse fixe, parce que
    /// c'est de la donnée brute et qu'elle se lit comme telle.
    public static let brut = Font.system(size: 13, design: .monospaced)

    // MARK: - Mesures

    /// Compteurs (nombre d'items, taille), horodatage relatif : chiffres à
    /// chasse fixe pour que la largeur ne tremble pas.
    public static let mesure = Font.system(size: 12, design: .rounded).monospacedDigit()

    // MARK: - Interlignes de lecture

    /// L'interligne ajouté au corps d'une note. +3 sur du 16 donne le régime
    /// d'une note qu'on relit, pas d'un libellé. Valeur typographique, HORS de la
    /// grille `Trame`.
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
