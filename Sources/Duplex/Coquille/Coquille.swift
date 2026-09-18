// La coquille du monde Duplex : un seul écran, et rien d'autre. Elle ne contient
// aucune donnée et aucune règle de forme — elle tient le duplexeur et laisse
// l'écran décider du reste.
#if canImport(SwiftUI)
import SwiftUI

public struct Coquille: View {
    @Environment(\.scenePhase) private var phase
    @State private var duplexeur = Duplexeur()

    public init() {}

    public var body: some View {
        EcouteEcran()
            .environment(duplexeur)
            .preferredColorScheme(.dark)
            .task { await duplexeur.demarrer() }
            .onChange(of: phase) { _, nouvelle in reagir(nouvelle) }
    }

    /// `☠` L'arrière-plan arrête la DÉCOUVERTE, jamais l'écoute. Couper le son
    /// parce que l'écran s'éteint serait l'inverse de ce qu'on demande à une
    /// enceinte — et le maintien en vie du centre tient déjà le processus.
    /// `.inactive` (bandeau de notification) ne suspend rien.
    private func reagir(_ nouvelle: ScenePhase) {
        switch nouvelle {
        case .background: duplexeur.suspendreDecouverte()
        case .active: duplexeur.reprendreDecouverte()
        default: break
        }
    }
}
#endif
