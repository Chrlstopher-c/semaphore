// Les voix de « La Besace ». Elles viennent du socle `Systeme` : serif
// éditorial pour les titres, sans système pour le courant, chasse fixe pour la
// donnée brute. Saily perd son dessin arrondi — c'est le prix de la cohérence :
// la distinction entre mondes ne passe plus par la police, elle passe par
// l'accent. Une seule voix, trois couleurs.
//
// `☠` Chaque voix reste bâtie sur un TEXT STYLE SYSTÈME (`.title`, `.body`,
// `.footnote`…), jamais sur une taille en dur : c'est ce qui fait grossir toute
// l'app avec les réglages d'accessibilité (Dynamic Type).
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Typo {
    // MARK: - Ce qui s'adresse à Chris — socle `Voix`, Dynamic Type

    /// Titre d'écran. Le seul grand pas typographique de la hiérarchie.
    public static let titreEcran = Voix.titreEcran
    public static let titreSection = Voix.titreSection
    /// Le corps d'une note : le texte qu'on relit dans l'inbox.
    public static let corps = Voix.corps
    public static let entete = Voix.entete
    public static let mention = Voix.mention
    public static let note = Voix.note
    public static let legende = Voix.legende

    // MARK: - Ce qui vient d'une machine — socle `Voix`, chasse fixe

    /// Un lien affiché tel quel, un nom de blob : chasse fixe, parce que c'est de
    /// la donnée brute et qu'elle se lit comme telle.
    public static let brut = Voix.brut

    // MARK: - Mesures

    /// Compteurs (nombre d'items, taille), horodatage relatif : chiffres à
    /// chasse fixe pour que la largeur ne tremble pas, mais taille relative.
    public static let mesure = Voix.mesure

    // MARK: - Interlignes de lecture

    /// L'interligne ajouté au corps d'une note : le régime d'une note qu'on
    /// relit, pas d'un libellé. Valeur typographique, HORS de la grille `Trame`.
    public static let interligneNote = Voix.interligne
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
