// Le mouvement et le retour tactile viennent du socle `Systeme` : les ressorts
// de `Mouvement`, le mappage haptique de `Toucher`. Le socle fournit aussi
// `AnyTransition.item` et `entreeEnScene(rang:)` — plus aucune définition
// locale ici, une extension dupliquée serait une collision.
//
// `☠` Une inbox est une LISTE qui bouge : un item capturé apparaît, un item
// supprimé part, un tri d'épingle réordonne. Ces mouvements passent par des
// identités STABLES (`id` d'`Item`) et des transitions ciblées — jamais par la
// reconstruction d'une liste dont les identifiants changeraient à chaque relevé,
// qui rejouerait toutes les entrées et ferait clignoter l'écran.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Elan {
    /// Appui, bascule, sélection, épingle. Le plus court, presque sans dépassement.
    public static let micro = Mouvement.micro
    /// Défaut : apparitions, changements d'état, réordonnancement de liste.
    public static let normal = Mouvement.normal
    /// Grandes surfaces : feuille de capture, aperçu plein écran.
    public static let surface = Mouvement.surface

    /// Apparition en cascade : 0,04 s par rang, six rangs au plus, puis tout
    /// arrive ensemble. Le septième item d'une liste n'attend personne.
    public static func cascade(_ rang: Int) -> Animation {
        Mouvement.cascade(rang)
    }

    /// L'apparition dépouillée pour « Réduire les animations » : un fondu court,
    /// aucun déplacement. Jamais rien de figé — un contenu qui surgit sans
    /// transition est aussi brutal qu'un contenu qui rebondit.
    public static let fonduReduit = Mouvement.fonduReduit
}

/// Un état, un retour — aliases historiques vers le mappage `Toucher` du socle.
/// Jamais deux retours pour un geste, jamais de retour décoratif.
public enum Retour {
    /// Appui sur un contrôle, sélection.
    public static let contact = Toucher.contact
    /// Action qui aboutit : item capturé, item épinglé.
    public static let engage = Toucher.engage
    /// Bascule d'onglet.
    public static let bascule = Toucher.selection
    /// Geste refusé : capture vide, serveur injoignable au test.
    ///
    /// `☠` La butée n'est pas facultative. Sans retour, la main croit que l'app
    /// n'a pas senti le doigt, et Chris rappuie.
    public static let butee = Toucher.butee
}
#endif
