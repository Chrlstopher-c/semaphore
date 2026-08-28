// La trame : espacements, galbes, trait. Six espacements, trois galbes — une
// grille assez courte pour être retenue, donc respectée.
#if canImport(SwiftUI)
import Foundation

public enum Trame {
    /// 4 — respiration minimale entre deux lignes liées.
    public static let fin: CGFloat = 4
    /// 8 — éléments d'une même rangée.
    public static let serre: CGFloat = 8
    /// 12 — blocs d'un même panneau.
    public static let element: CGFloat = 12
    /// 16 — panneaux entre eux, marge interne d'un panneau.
    public static let bloc: CGFloat = 16
    /// 20 — marge horizontale d'écran.
    public static let ecran: CGFloat = 20
    /// 28 — sections entre elles.
    public static let section: CGFloat = 28

    /// Épaisseur d'un filet.
    public static let trait: CGFloat = 1

    /// Hauteur minimale d'une cible tactile. Les boutons de décision montent
    /// à `cibleDecision` : la géométrie du pouce prime sur la densité.
    public static let cible: CGFloat = 44
    public static let cibleDecision: CGFloat = 50
}

public enum Galbe {
    /// Encarts internes (voiles, blocs de code).
    public static let encart: CGFloat = 10
    public static let bouton: CGFloat = 12
    public static let panneau: CGFloat = 14
}
#endif
