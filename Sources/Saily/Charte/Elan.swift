// Le mouvement et le retour tactile. Trois ressorts, un mappage haptique fixe.
//
// L'appareil plafonne à 60 Hz : les trajets sont courts, les ressorts calmes, et
// seuls `transform` et `opacity` sont animés — animer un flou, une ombre ou la
// mise en page d'une grosse hiérarchie se voit ramer.
//
// `☠` Une inbox est une LISTE qui bouge : un item capturé apparaît, un item
// supprimé part, un tri d'épingle réordonne. Ces mouvements passent par des
// identités STABLES (`id` d'`Item`) et des transitions ciblées — jamais par la
// reconstruction d'une liste dont les identifiants changeraient à chaque relevé,
// qui rejouerait toutes les entrées et ferait clignoter l'écran.
#if canImport(SwiftUI)
import SwiftUI

// `☠` Ressorts NATIFS, pas des courbes de durée : `response` ~0,2–0,4 s et
// `dampingFraction` 0,85–0,9 — un soupçon de vie, jamais de rebond marqué. C'est
// le toucher Apple ; une courbe linéaire ou un `bounce` franc trahit le web
// porté à la va-vite. Tout reste sous le plafond des 400 ms perçus.
public enum Elan {
    /// Appui, bascule, sélection, épingle. Le plus court, presque sans dépassement.
    public static let micro = Animation.spring(response: 0.22, dampingFraction: 0.9)
    /// Défaut : apparitions, changements d'état, réordonnancement de liste.
    public static let normal = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// Grandes surfaces : feuille de capture, aperçu plein écran.
    public static let surface = Animation.spring(response: 0.4, dampingFraction: 0.85)

    /// Apparition en cascade : 0,04 s par rang, six rangs au plus, puis tout
    /// arrive ensemble. Le septième item d'une liste n'attend personne.
    public static func cascade(_ rang: Int) -> Animation {
        normal.delay(Double(min(max(rang, 0), 6)) * 0.04)
    }

    /// L'apparition dépouillée pour « Réduire les animations » : un fondu court,
    /// aucun déplacement. Jamais rien de figé — un contenu qui surgit sans
    /// transition est aussi brutal qu'un contenu qui rebondit.
    public static let fonduReduit = Animation.easeOut(duration: 0.15)
}

/// Un état, un retour. Jamais deux pour un geste, jamais de retour décoratif.
public enum Retour {
    /// Appui sur un contrôle, sélection.
    public static let contact = SensoryFeedback.impact(weight: .light)
    /// Action qui aboutit : item capturé, item épinglé.
    public static let engage = SensoryFeedback.impact(weight: .medium)
    /// Bascule d'onglet.
    public static let bascule = SensoryFeedback.selection
    /// Geste refusé : capture vide, serveur injoignable au test.
    ///
    /// `☠` La butée n'est pas facultative. Sans retour, la main croit que l'app
    /// n'a pas senti le doigt, et Chris rappuie.
    public static let butee = SensoryFeedback.warning
}

extension AnyTransition {
    /// L'entrée et la sortie d'un item de liste, en un seul jeton : on entre en
    /// se levant de 10 pt dans un fondu, on sort en s'éteignant sur place.
    ///
    /// L'asymétrie est le principe : un item qui part ne doit pas attirer l'œil
    /// sur son départ, seulement libérer la place.
    public static var item: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .offset(y: 10)), removal: .opacity)
    }
}

extension View {
    /// Entrée en scène d'un élément nouveau : fondu et léger soulèvement.
    ///
    /// `☠` À poser sur des vues à identité STABLE. Sur une liste dont les
    /// identifiants changent à chaque relevé, chaque rafraîchissement rejouerait
    /// l'entrée — le clignotement qu'on interdit.
    ///
    /// `☠` Respecte « Réduire les animations » : en mode réduit, un simple fondu,
    /// sans déplacement — le glissement est justement ce qui gêne les personnes
    /// sensibles au mouvement.
    public func entreeEnScene(rang: Int = 0) -> some View {
        modifier(EntreeEnScene(rang: rang))
    }
}

private struct EntreeEnScene: ViewModifier {
    let rang: Int
    @Environment(\.accessibilityReduceMotion) private var reduireMouvement
    @State private var posee = false

    func body(content: Content) -> some View {
        content
            .opacity(posee ? 1 : 0)
            .offset(y: decalage)
            .onAppear {
                withAnimation(reduireMouvement ? Elan.fonduReduit : Elan.cascade(rang)) {
                    posee = true
                }
            }
    }

    private var decalage: CGFloat {
        if reduireMouvement { return 0 }
        return posee ? 0 : 10
    }
}
#endif
