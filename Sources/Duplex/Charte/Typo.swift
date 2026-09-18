// Les voix viennent du socle `Systeme` (`Voix`) et les écrans les écrivent
// directement. Ne s'ajoutent ici que les deux voix sans équivalent socle, et
// la tête de rubrique.
//
// `☠` Chaque voix reste bâtie sur un TEXT STYLE SYSTÈME, jamais sur une taille
// en dur : c'est ce qui fait grossir toute l'app avec Dynamic Type.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

extension Voix {
    /// Un chiffre du code de jumelage : chasse fixe et grand, parce qu'on le
    /// recopie d'un écran à l'autre en comparant chiffre à chiffre.
    public static let code = Font.system(.title, design: .monospaced, weight: .semibold).monospacedDigit()
    /// Le nom du PC dans la salle d'écoute : la seule chose à lire sur un écran
    /// qu'on regarde longtemps et de loin — un pas au-dessus du titre d'écran.
    public static let nomPoste = Font.system(.largeTitle, design: .serif, weight: .semibold)
}

extension View {
    /// Tête de rubrique : capitales espacées, éteintes. La section s'annonce à
    /// voix basse — c'est le contenu qui parle.
    public func rubrique() -> some View {
        font(Voix.legende)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Neutre.encreEteinte)
    }
}
#endif
