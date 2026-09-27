// Les voix viennent du socle `Systeme`. Ne s'ajoutent ici que les chiffres
// propres à Tamis et la tête de rubrique.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

extension Voix {
    /// Le poids de la photothèque en tête des Strates : le chiffre qu'on vient
    /// faire baisser. Serif comme les titres, un cran au-dessus.
    public static let poidsHeros = Font.system(.largeTitle, design: .serif, weight: .semibold).monospacedDigit()
    /// L'année d'une strate.
    public static let annee = Font.system(.title3, design: .serif, weight: .semibold).monospacedDigit()
}

extension View {
    /// Tête de rubrique : capitales espacées, éteintes.
    public func rubrique() -> some View {
        font(Voix.legende)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Neutre.encreEteinte)
    }
}
#endif
