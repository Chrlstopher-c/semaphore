// Étage inline du rendu markdown : `[FragmentTexte]` → `Text`.
//
// Chaque fragment devient un `AttributedString` porteur d'un
// `InlinePresentationIntent` (gras/italique/code/barré) plutôt qu'un `Font`
// fixé : le fragment HÉRITE du style posé par le conteneur, exactement comme
// le ferait `AttributedString(markdown:)`.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Concatène des fragments en un seul `Text` stylé.
func texteFragments(_ fragments: [FragmentTexte]) -> Text {
    fragments.reduce(Text(verbatim: "")) { accumule, fragment in
        accumule + Text(fragment.attribue)
    }
}

extension FragmentTexte {
    /// `☠` Le code inline se rend SANS fond ni bordure (relevé prod) :
    /// encadrer chaque terme technique fabrique des pavés qui hachent la
    /// ligne. Seule la police change — c'est l'intention `.code`.
    fileprivate var attribue: AttributedString {
        var chaine = AttributedString(texte)
        var intention: InlinePresentationIntent = []
        if styles.contains(.gras) { intention.insert(.stronglyEmphasized) }
        if styles.contains(.italique) { intention.insert(.emphasized) }
        if styles.contains(.code) { intention.insert(.code) }
        if styles.contains(.barre) { intention.insert(.strikethrough) }
        if !intention.isEmpty { chaine.inlinePresentationIntent = intention }
        if let lien, let cible = URL(string: lien) {
            chaine.link = cible
            chaine.foregroundColor = Teinte.accent
            chaine.underlineStyle = .single
        }
        return chaine
    }
}
#endif
