// Le seul jeton de couleur propre à Lueur : son accent. Le reste vient du socle `Systeme`,
// et la couleur vivante du ruban n'est jamais un jeton — c'est une donnée. Choix et emplois : `CHARTE.md`.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Teinte {
    /// Orange incandescent — le chrome du monde (sélecteur, contrôles système).
    public static let accent = Color(socle: 0xFF8A3D)
}

extension View {
    /// Tête de rubrique : capitales espacées, éteintes (même geste qu'Iris, dupliqué exprès).
    func rubrique() -> some View {
        font(Voix.legende)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Neutre.encreEteinte)
    }
}

/// Les dimensions propres au monde — des tailles de composant, pas des espacements.
enum Trame {
    /// La roue : 280 pt, 84 % des 335 pt utiles — le focal pèse plus du double du reste.
    static let roue: CGFloat = 280
    /// L'interrupteur au cœur de la roue.
    static let interrupteur: CGFloat = 96
    /// Le curseur posé sur la roue.
    static let curseur: CGFloat = 28
    /// Une pastille de couleur : six par rangée dans 335 pt, 44 pt de cible.
    static let pastille: CGFloat = 44
    /// Le halo de la couleur vivante derrière la roue.
    static let halo: CGFloat = 50
}
#endif
