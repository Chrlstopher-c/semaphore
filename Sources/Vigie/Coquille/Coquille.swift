// La coquille de Vigie : connexion, ou cinq onglets natifs (Sessions, Parc, Accès, Alertes, Réglages) à la teinte Echo.
// Le pupitre laisse Vigie suivre le mode de l'iPhone (clair / sombre) quand elle est au premier plan.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

public struct Coquille: View {
    enum Onglet: Hashable { case sessions, parc, acces, alertes, reglages }

    @Environment(Cablage.self) private var cablage
    @Environment(\.scenePhase) private var phase
    @State private var onglet = Onglet.sessions
    @State private var pile = NavigationPath()

    public init() {}

    public var body: some View {
        Group {
            if cablage.connecte { onglets } else { ConnexionEcran() }
        }
        .tint(Charte.accent)
        .task { await cablage.amorcer() }
        .onChange(of: phase) { _, nouvelle in suivrePhase(nouvelle) }
        .onChange(of: Aiguillage.partage.sessionDemandee) { _, id in ouvrirDemandee(id) }
    }

    private var onglets: some View {
        TabView(selection: $onglet) {
            Tab("Sessions", systemImage: "bubble.left.and.text.bubble.right", value: .sessions) {
                NavigationStack(path: $pile) {
                    ListeSessionsEcran().navigationDestination(for: String.self) { SessionEcran(id: $0) }
                }
            }
            .badge(cablage.modele.sessions.filter { $0.statut == .question }.count)
            Tab("Parc", systemImage: "server.rack", value: .parc) { ParcEcran() }
            Tab("Accès", systemImage: "externaldrive.connected.to.line.below", value: .acces) { AccesEcran() }
            Tab("Alertes", systemImage: "bell", value: .alertes) { AlertesEcran(ouvrir: ouvrir) }
                .badge(cablage.modele.notifications.filter { !$0.lue && $0.niveau != .info }.count)
            Tab("Réglages", systemImage: "gearshape", value: .reglages) { ReglagesEcran() }
        }
    }

    private func ouvrir(_ id: String) {
        onglet = .sessions
        pile = NavigationPath([id])
    }

    private func ouvrirDemandee(_ id: String?) {
        guard let id else { return }
        ouvrir(id)
        Aiguillage.partage.sessionDemandee = nil
    }

    /// Premier plan : long-poll actif ; arrière-plan : la veille (audio, réveils de fond) prend le relais.
    private func suivrePhase(_ nouvelle: ScenePhase) {
        switch nouvelle {
        case .active:
            cablage.modele.demarrer()
            Task { await CentreAlerte.partage.sonder(origine: .ouverture) }
        case .background: cablage.modele.arreter()
        default: break
        }
    }
}
#endif
