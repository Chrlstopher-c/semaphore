// La trame, adossée à la grille du socle `Systeme`. Les noms historiques
// restent : les composants écrivent `Trame.bloc`, `Galbe.encart` sans
// changement — les valeurs viennent de `Grille` et `Rayon`.
#if canImport(SwiftUI)
import Foundation
import Systeme

public enum Trame {
    /// 4 — respiration minimale entre deux lignes liées.
    public static let fin = Grille.fin
    /// 8 — éléments d'une même rangée.
    public static let serre = Grille.serre
    /// 12 — blocs d'un même panneau.
    public static let element = Grille.element
    /// 16 — panneaux entre eux, marge interne d'un panneau.
    public static let bloc = Grille.bloc
    /// 20 — marge horizontale d'écran.
    public static let ecran = Grille.ecran
    /// 32 — sections entre elles (l'échelle socle remplace le 28 historique).
    public static let section = Grille.section

    /// Épaisseur d'un filet.
    public static let trait = Grille.trait

    /// Hauteur minimale d'une cible tactile. Les boutons de décision montent
    /// à `cibleDecision` : la géométrie du pouce prime sur la densité.
    public static let cible = Grille.cible
    /// Propre à Vigie — le socle n'a qu'une cible ; les gestes de décision de
    /// Vigie gardent leur surhauteur.
    public static let cibleDecision: CGFloat = 50
}

public enum Galbe {
    /// Encarts internes (voiles, blocs de code).
    public static let encart = Rayon.controle
    public static let bouton = Rayon.controle
    public static let panneau = Rayon.carte
}
#endif
