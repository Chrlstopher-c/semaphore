// La coquille de Quart : l'appairage tant qu'aucune clé n'est rangée, puis la racine (liste Code, tiroir, sessions).
// Toujours sombre, comme l'étalon. La veille et les notifications natives sont celles de Vigie, inchangées.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

public struct Coquille: View {
    @Environment(Cablage.self) private var cablage
    @Environment(\.scenePhase) private var phase
    @State private var pile: [String] = []

    public init() {}

    public var body: some View {
        Group {
            if cablage.connecte { RacineQuart(pile: $pile) } else { ConnexionEcran() }
        }
        .preferredColorScheme(.dark)
        .tint(Q.coche)
        .task {
            await cablage.amorcer()
            cablage.modele.demarrer()
            ouvrirDemandee(Aiguillage.partage.sessionDemandee)
        }
        // Monde quitté : le flux direct s'arrête ; la veille et les alertes, tenues par le câblage, continuent.
        .onDisappear { cablage.modele.arreter() }
        .onChange(of: phase) { _, nouvelle in suivrePhase(nouvelle) }
        .onChange(of: Aiguillage.partage.sessionDemandee) { _, id in ouvrirDemandee(id) }
    }

    private func ouvrirDemandee(_ id: String?) {
        guard let id else { return }
        pile = [id]
        Aiguillage.partage.sessionDemandee = nil
    }

    /// Premier plan : flux en direct ; arrière-plan : la veille (audio, réveils de fond) prend le relais.
    private func suivrePhase(_ nouvelle: ScenePhase) {
        switch nouvelle {
        case .active:
            cablage.modele.demarrer()
            Task { await cablage.verifierLiaisons() }
            Task { await CentreAlerte.partage.sonder(origine: .ouverture) }
        case .background: cablage.modele.arreter()
        default: break
        }
    }
}

/// Ouvre le tiroir depuis n'importe quel écran de la pile (bouton à trois traits de l'en-tête).
private struct CleOuvrirTiroir: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var ouvrirTiroir: @MainActor @Sendable () -> Void {
        get { self[CleOuvrirTiroir.self] }
        set { self[CleOuvrirTiroir.self] = newValue }
    }
}

/// Le glissement de retour reste actif même quand l'en-tête remplace la flèche par le bouton du tiroir.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
#endif
