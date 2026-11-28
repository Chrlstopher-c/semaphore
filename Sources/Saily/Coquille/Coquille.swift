// La coquille de « La Besace » : trois onglets, et rien d'autre. Elle ne
// contient aucune donnée et aucune règle de forme — elle pose l'ambiance racine,
// tient la besace, et laisse chaque pièce décider du reste.
#if canImport(SwiftUI)
import SwiftUI
import SailyNoyau

public struct Coquille: View {
    @Environment(\.scenePhase) private var phase
    // Le pupitre démonte le monde quitté : la besace et l'onglet survivent au retour.
    @State private var boite = Boite.memoire
    @SceneStorage("saily.onglet") private var onglet: Onglet = .inbox

    public init() {}

    public var body: some View {
        TabView(selection: $onglet) {
            Tab(Onglet.inbox.libelle, systemImage: Onglet.inbox.symbole, value: .inbox) {
                InboxEcran(surCapturer: { onglet = .capture })
            }
            Tab(Onglet.capture.libelle, systemImage: Onglet.capture.symbole, value: .capture) {
                CaptureEcran(surCapture: { onglet = .inbox })
            }
            Tab(Onglet.coffre.libelle, systemImage: Onglet.coffre.symbole, value: .coffre) {
                CoffreEcran()
            }
            Tab(Onglet.reglages.libelle, systemImage: Onglet.reglages.symbole, value: .reglages) {
                ReglagesEcran()
            }
        }
        .tint(Teinte.accent)
        .environment(boite)
        .ambiance(Ambiance())
        .preferredColorScheme(.dark)
        .sensoryFeedback(Retour.bascule, trigger: onglet)
        .task { if boite.demarree { await boite.reprendre() } else { await boite.demarrer() } }
        // Monde quitté : le socket se ferme, la besace reste en mémoire.
        .onDisappear { boite.suspendre() }
        .onChange(of: phase) { _, nouvelle in reagir(nouvelle) }
    }

    /// Le socket est ré-ouvert au réveil et fermé en arrière-plan. `.inactive`
    /// (bandeau de notification) ne suspend rien — seul `.background` le fait.
    private func reagir(_ nouvelle: ScenePhase) {
        switch nouvelle {
        case .background: boite.suspendre()
        case .active: Task { await boite.reprendre() }
        default: break
        }
    }
}

/// Quatre onglets : voir ce qu'on a capturé, capturer, le coffre de la tour, et régler la liaison.
public enum Onglet: String, Hashable, CaseIterable {
    case inbox, capture, coffre, reglages

    public var libelle: String {
        switch self {
        case .inbox: return "Besace"
        case .capture: return "Capturer"
        case .coffre: return "Coffre"
        case .reglages: return "Réglages"
        }
    }

    public var symbole: String {
        switch self {
        case .inbox: return "tray.full"
        case .capture: return "plus.circle"
        case .coffre: return "lock.shield"
        case .reglages: return "slider.horizontal.3"
        }
    }
}
#endif
