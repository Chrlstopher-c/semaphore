// Les voix communes. UNE échelle typographique pour toute l'app : serif
// éditorial pour les titres (le New York d'Apple, obtenu par `design: .serif` —
// aucune police embarquée), sans système pour tout le courant, chasse fixe pour
// la donnée brute et les mesures.
//
// `☠` Chaque voix est bâtie sur un TEXT STYLE SYSTÈME (`.title`, `.body`…),
// jamais sur une taille en dur : c'est ce qui fait grossir toute l'app avec les
// réglages d'accessibilité (Dynamic Type). Une taille figée (`size: 20`) ignore
// ces réglages — le défaut que ce système bannit dans les trois mondes.
//
// La distinction entre mondes ne passe PLUS par la police (avant : serif chez
// Vigie, rond chez Saily, neutre chez EchoHub) : elle passe par l'accent. Une
// seule voix, trois couleurs.
#if canImport(SwiftUI)
import SwiftUI

public enum Voix {
    // MARK: - Titres — serif éditorial, Dynamic Type

    /// Titre d'écran. Le seul grand pas typographique de la hiérarchie.
    public static let titreEcran = Font.system(.title, design: .serif, weight: .semibold)
    /// Titre de section, titre de carte.
    public static let titreSection = Font.system(.title3, design: .serif, weight: .semibold)

    // MARK: - Courant — sans système (SF Pro), Dynamic Type

    /// Le corps de lecture.
    public static let corps = Font.system(.body)
    /// Libellé d'action, entête de bloc.
    public static let entete = Font.system(.body, weight: .semibold)
    /// Le secondaire courant : mentions, descriptions.
    public static let mention = Font.system(.subheadline, weight: .medium)
    /// Note, détail éteint.
    public static let note = Font.system(.footnote)
    /// Légende, tête de rubrique.
    public static let legende = Font.system(.caption, weight: .medium)

    // MARK: - Machine — chasse fixe, Dynamic Type

    /// Un lien tel quel, un nom de blob, une sortie brute : chasse fixe car c'est
    /// de la donnée qui se lit comme telle. Sur `.footnote` pour suivre Dynamic
    /// Type malgré le dessin monospacé.
    public static let brut = Font.system(.footnote, design: .monospaced)
    /// Compteurs, horodatage, mesures : chiffres à chasse fixe pour que la
    /// largeur ne tremble pas, mais taille relative.
    public static let mesure = Font.system(.caption, design: .monospaced).monospacedDigit()

    // MARK: - Interligne de lecture — valeur typographique, hors grille

    /// Ajouté au corps d'un texte long qu'on relit (une note, une réponse).
    public static let interligne: CGFloat = 3
}
#endif
