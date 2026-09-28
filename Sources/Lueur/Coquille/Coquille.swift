// La coquille du monde Lueur : tient la lampe et lui dit si le monde est devant.
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct Coquille: View {
    private let visible: Bool
    private let lampe = Lampe.partage

    /// `visible` : le Pi n'est sondé que monde devant ; monté d'office par le pupitre, Lueur n'ouvre rien au lancement.
    public init(visible: Bool) {
        self.visible = visible
    }

    public var body: some View {
        LueurEcran()
            .tint(Teinte.accent)
            .preferredColorScheme(.dark)
            .onChange(of: visible, initial: true) { _, devant in lampe.montrer(devant) }
            .environment(lampe)
    }
}
#endif
