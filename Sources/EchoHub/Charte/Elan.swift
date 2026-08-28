// Le mouvement et le retour tactile — le moteur du socle `Systeme`, sous les
// noms historiques d'EchoHub. Ressorts natifs, cascade, mappage haptique fixe.
//
// `☠` La règle la plus facile à casser d'une app de chat, et la plus
// insupportable à l'usage : un token qui arrive ne doit JAMAIS déplacer une
// ligne que Chris est en train de lire. Le texte déjà écrit ne bouge pas, et la
// position de défilement n'est reprise que si elle était déjà en bas.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Elan {
    /// Appui, bascule, sélection.
    public static let micro = Mouvement.micro
    /// Défaut : apparitions, changements d'état.
    public static let normal = Mouvement.normal
    /// Grandes surfaces : dépliage d'un bloc de raisonnement, feuille.
    public static let surface = Mouvement.surface
    /// Ce qui réagit PENDANT qu'un doigt guide. Aucun emploi recensé à ce
    /// jour : rabattu sur le ressort le plus court du socle.
    public static let suivi = Mouvement.micro

    /// Apparition en cascade : 0,04 s par rang, six rangs au plus, puis tout
    /// arrive ensemble. Le septième élément d'une liste n'attend personne.
    public static func cascade(_ rang: Int) -> Animation {
        Mouvement.cascade(rang)
    }
}

/// Un état, un retour. Jamais deux pour un geste, jamais de retour décoratif.
/// Le mappage vient du socle `Toucher`, sous les noms historiques.
public enum Retour {
    /// Appui sur un contrôle, sélection dans une liste.
    public static let contact = Toucher.contact
    /// Action qui aboutit : message envoyé, réponse terminée.
    public static let engage = Toucher.engage
    /// Bascule d'onglet.
    public static let bascule = Toucher.selection
    /// Geste refusé : envoi sans modèle chargé, relais injoignable.
    ///
    /// `☠` La butée n'est pas facultative. Sans retour, la main croit que l'app
    /// n'a pas senti le doigt, et Chris rappuie.
    public static let butee = Toucher.butee
}

extension AnyTransition {
    /// Le nom historique d'EchoHub pour l'entrée/sortie d'item — pointe sur le
    /// jeton `item` du socle : levée en fondu à l'entrée, extinction sur place
    /// à la sortie.
    public static var scene: AnyTransition { .item }
}

#endif
