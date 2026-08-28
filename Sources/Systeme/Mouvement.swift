// Le mouvement commun — le cœur de l'immersion. Un seul moteur d'animation pour
// toute l'app, au lieu de trois qui se contredisaient : ressorts natifs pour le
// toucher, cascade pour les listes, une bascule profonde pour le passage d'un
// monde à l'autre, et un mappage haptique unique.
//
// `☠` Ressorts NATIFS, pas des courbes de durée : `response` ~0,2–0,4 s et
// `dampingFraction` 0,85–0,9 — un soupçon de vie, jamais de rebond marqué. C'est
// le toucher Apple ; une courbe linéaire ou un `bounce` franc trahit le web
// porté à la va-vite. Tout reste sous le plafond des 400 ms perçus.
//
// `☠` Seuls `transform` et `opacity` sont animés. Animer un flou, une ombre ou
// la mise en page d'une grosse hiérarchie se voit ramer sur un écran 60 Hz.
//
// `☠` TOUT trajet respecte « Réduire les animations ». Un contenu qui surgit
// sans transition est aussi brutal qu'un contenu qui rebondit : en mode réduit,
// un fondu court remplace le déplacement, jamais rien de figé.
#if canImport(SwiftUI)
import SwiftUI

public enum Mouvement {
    /// Appui, bascule, sélection. Le plus court, presque sans dépassement.
    public static let micro = Animation.spring(response: 0.22, dampingFraction: 0.9)
    /// Défaut : apparitions, changements d'état, réordonnancement de liste.
    public static let normal = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// Grandes surfaces : feuille, aperçu plein écran, bascule de monde.
    public static let surface = Animation.spring(response: 0.42, dampingFraction: 0.85)

    /// L'apparition dépouillée pour « Réduire les animations » : un fondu court,
    /// aucun déplacement.
    public static let fonduReduit = Animation.easeOut(duration: 0.16)

    /// Apparition en cascade : 0,04 s par rang, six rangs au plus, puis tout
    /// arrive ensemble. Le septième item d'une liste n'attend personne.
    public static func cascade(_ rang: Int) -> Animation {
        normal.delay(Double(min(max(rang, 0), 6)) * 0.04)
    }
}

extension AnyTransition {
    /// L'entrée et la sortie d'un item de liste : on entre en se levant de 10 pt
    /// dans un fondu, on sort en s'éteignant sur place.
    ///
    /// L'asymétrie est le principe : un item qui part ne doit pas attirer l'œil
    /// sur son départ, seulement libérer la place.
    public static var item: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .offset(y: 10)), removal: .opacity)
    }

    /// La bascule d'un monde à l'autre — la transition la plus immersive de
    /// l'app. Le monde entrant avance vers soi (léger zoom depuis 1,02), le monde
    /// sortant recule (vers 0,98), les deux en fondu. Profond, pas directionnel :
    /// on ne « glisse » pas d'un monde à un voisin, on plonge dans un autre.
    ///
    /// `☠` Uniquement `scale` + `opacity` : aucun flou (il ramerait), aucune
    /// mise en page animée.
    public static var monde: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 1.02, anchor: .center)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .center))
        )
    }
}

extension View {
    /// Entrée en scène d'un élément nouveau : fondu et léger soulèvement, décalé
    /// selon son rang pour la cascade.
    ///
    /// `☠` À poser sur des vues à identité STABLE. Sur une liste dont les
    /// identifiants changent à chaque relevé, chaque rafraîchissement rejouerait
    /// l'entrée — un clignotement qu'on interdit.
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
                withAnimation(reduireMouvement ? Mouvement.fonduReduit : Mouvement.cascade(rang)) {
                    posee = true
                }
            }
    }

    private var decalage: CGFloat {
        if reduireMouvement { return 0 }
        return posee ? 0 : 10
    }
}

/// Un état, un retour. Superset couvrant les trois mondes : jamais deux retours
/// pour un geste, jamais de retour décoratif.
///
/// `☠` La butée n'est pas facultative. Sans retour sur un geste refusé, la main
/// croit que l'app n'a pas senti le doigt, et Chris rappuie.
public enum Toucher {
    /// Appui sur un contrôle.
    public static let contact = SensoryFeedback.impact(weight: .light)
    /// Bascule d'onglet, de monde, de filtre.
    public static let selection = SensoryFeedback.selection
    /// Action qui engage : capturer, enregistrer, tester.
    public static let engage = SensoryFeedback.impact(weight: .medium)
    /// Action qui aboutit franchement : service relancé, item confirmé.
    public static let reussite = SensoryFeedback.success
    /// Geste refusé : saisie vide, serveur injoignable.
    public static let butee = SensoryFeedback.warning
    /// Incident réel signalé pendant qu'on regarde : un service tombe.
    public static let alerte = SensoryFeedback.error
    /// L'engagement lourd : un geste dont on veut sentir le poids.
    public static let engagement = SensoryFeedback.impact(weight: .heavy)
}
#endif
