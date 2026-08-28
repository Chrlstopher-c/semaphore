// Le mouvement et le retour tactile. Quatre ressorts, un mappage haptique fixe.
//
// L'appareil plafonne à 60 Hz : les trajets sont courts, les ressorts calmes, et
// seuls `transform` et `opacity` sont animés — animer un flou, une ombre ou la
// mise en page d'une grosse hiérarchie se voit ramer sur A12.
//
// `☠` La règle la plus facile à casser d'une app de chat, et la plus
// insupportable à l'usage : un token qui arrive ne doit JAMAIS déplacer une
// ligne que Chris est en train de lire. Le texte déjà écrit ne bouge pas, et la
// position de défilement n'est reprise que si elle était déjà en bas.
#if canImport(SwiftUI)
import SwiftUI

public enum Elan {
    /// Appui, bascule, sélection.
    public static let micro = Animation.snappy(duration: 0.2)
    /// Défaut : apparitions, changements d'état.
    public static let normal = Animation.spring(duration: 0.35, bounce: 0)
    /// Grandes surfaces : dépliage d'un bloc de raisonnement, feuille.
    public static let surface = Animation.smooth(duration: 0.45)
    /// Ce qui réagit PENDANT qu'un doigt guide. Ce qui suit le doigt lui-même
    /// n'est jamais animé — une surface qui traîne derrière le pouce se sent
    /// immédiatement.
    public static let suivi = Animation.interactiveSpring(duration: 0.25, extraBounce: 0)

    /// `bounce` reste à 0 partout : un rebond sur un texte en train de s'écrire
    /// fait jouet.
    ///
    /// Apparition en cascade : 0,04 s par rang, six rangs au plus, puis tout
    /// arrive ensemble. Le septième élément d'une liste n'attend personne.
    public static func cascade(_ rang: Int) -> Animation {
        normal.delay(Double(min(max(rang, 0), 6)) * 0.04)
    }
}

/// Un état, un retour. Jamais deux pour un geste, jamais de retour décoratif.
public enum Retour {
    /// Appui sur un contrôle, sélection dans une liste.
    public static let contact = SensoryFeedback.impact(weight: .light)
    /// Action qui aboutit : message envoyé, réponse terminée.
    public static let engage = SensoryFeedback.impact(weight: .medium)
    /// Bascule d'onglet.
    public static let bascule = SensoryFeedback.selection
    /// Geste refusé : envoi sans modèle chargé, relais injoignable.
    ///
    /// `☠` La butée n'est pas facultative. Sans retour, la main croit que l'app
    /// n'a pas senti le doigt, et Chris rappuie.
    public static let butee = SensoryFeedback.warning
}

extension AnyTransition {
    /// L'entrée et la sortie de toute l'app, en un seul jeton : on entre en se
    /// levant de 6 pt dans un fondu, on sort en s'éteignant sur place.
    ///
    /// L'asymétrie est le principe, pas un raffinement : un élément qui part ne
    /// doit pas attirer l'œil sur son départ, seulement libérer la place.
    public static var scene: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity)
    }
}

extension View {
    /// Entrée en scène d'un élément nouveau : fondu et léger soulèvement.
    ///
    /// `☠` À poser sur des vues à identité STABLE. Sur une liste dont les
    /// identifiants changent à chaque relevé, chaque rafraîchissement rejouerait
    /// l'entrée — c'est le clignotement qu'on interdit. En particulier : jamais
    /// sur un message en cours de génération, dont le contenu change à chaque
    /// fragment.
    public func entreeEnScene(rang: Int = 0) -> some View {
        modifier(EntreeEnScene(rang: rang))
    }
}

private struct EntreeEnScene: ViewModifier {
    let rang: Int
    @State private var posee = false

    func body(content: Content) -> some View {
        content
            .opacity(posee ? 1 : 0)
            .offset(y: posee ? 0 : 6)
            .onAppear { withAnimation(Elan.cascade(rang)) { posee = true } }
    }
}
#endif
