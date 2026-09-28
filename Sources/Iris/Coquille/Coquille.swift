// La coquille du monde Iris : tient l'émetteur et dit à l'écran s'il est devant.
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct Coquille: View {
    private let visible: Bool
    @State private var emetteur = Emetteur()

    /// `visible` : le relais n'est joint que monde devant ou flux en cours ;
    /// monté d'office par le pupitre, Iris ne doit rien ouvrir au lancement.
    public init(visible: Bool) {
        self.visible = visible
    }

    public var body: some View {
        IrisEcran()
            .tint(Teinte.accent)
            .preferredColorScheme(.dark)
            .onChange(of: visible, initial: true) { _, devant in emetteur.montrer(devant) }
            .environment(emetteur)
    }
}
#endif
