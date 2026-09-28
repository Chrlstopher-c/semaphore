// La coquille de Vigie : connexion ou quatre onglets (Sessions, Parc, Alertes, Réglages), au thème de l'iPhone.
// Le pupitre force le sombre pour toute l'app ; Vigie relit l'apparence réelle (celle de l'écran, que le pupitre ne
// force pas) et l'impose à son seul sous-arbre.
#if canImport(SwiftUI)
import SwiftUI
import UIKit
import VigieNoyau

public struct Coquille: View {
    enum Onglet: Hashable { case sessions, parc, alertes, reglages }

    @Environment(Cablage.self) private var cablage
    @Environment(\.scenePhase) private var phase
    @State private var schema = Coquille.apparenceSysteme()
    @State private var onglet = Onglet.sessions
    @State private var pile = NavigationPath()

    public init() {}

    public var body: some View {
        let palette = Palette.pour(schema)
        Group {
            if cablage.connecte { onglets(palette) } else { ConnexionEcran() }
        }
        .environment(\.colorScheme, schema)
        .environment(\.palette, palette)
        .task { await cablage.amorcer() }
        .onChange(of: phase) { _, nouvelle in suivrePhase(nouvelle) }
        .onChange(of: Aiguillage.partage.sessionDemandee) { _, id in ouvrirDemandee(id) }
    }

    private func onglets(_ p: Palette) -> some View {
        TabView(selection: $onglet) {
            Tab("Sessions", systemImage: "bubble.left.and.text.bubble.right", value: .sessions) {
                NavigationStack(path: $pile) {
                    ListeSessionsEcran().navigationDestination(for: String.self) { SessionEcran(id: $0) }
                }
            }
            .badge(cablage.modele.sessions.filter { $0.statut == .question }.count)
            Tab("Parc", systemImage: "server.rack", value: .parc) { ParcEcran() }
            Tab("Alertes", systemImage: "bell", value: .alertes) { AlertesEcran(ouvrir: ouvrir) }
                .badge(cablage.modele.notifications.filter { !$0.lue && $0.niveau != .info }.count)
            Tab("Réglages", systemImage: "gearshape", value: .reglages) { ReglagesEcran() }
        }
        .tint(p.accent)
        .toolbarBackground(p.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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

    /// Premier plan : long-poll actif et relecture de l'apparence ; arrière-plan : la veille prend le relais.
    private func suivrePhase(_ nouvelle: ScenePhase) {
        switch nouvelle {
        case .active:
            schema = Coquille.apparenceSysteme()
            cablage.modele.demarrer()
            Task { await CentreAlerte.partage.sonder(origine: .ouverture) }
        case .background: cablage.modele.arreter()
        default: break
        }
    }

    static func apparenceSysteme() -> ColorScheme {
        UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }
}
#endif
