// La coquille : les trois onglets du web (Sessions, Modèles, Système), et rien d'autre. Elle ne contient aucune donnée
// et aucune règle de forme — elle pose l'ambiance racine, tient le salon, et
// laisse chaque pièce décider du reste.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

public struct Coquille: View {
    @Environment(\.scenePhase) private var phase
    @State private var salon = Salon()
    @State private var onglet: Onglet = .sessions
    @AppStorage(ThemeEchoHub.cle) private var theme: ThemeEchoHub = .sombre
    @State private var tour: SuiviTour?
    /// Faut-il couper la génération quand l'app passe à l'arrière-plan ?
    /// Seule, l'app est suspendue par iOS en une à deux secondes — couper
    /// proprement vaut mieux qu'un flux mort. Hébergée dans un centre qui tient
    /// le processus en vie (session audio, localisation), la coupure n'a plus
    /// de raison d'être, et c'est l'hôte qui le dit.
    private let suspendreEnArrierePlan: @MainActor () -> Bool

    public init(suspendreEnArrierePlan: @escaping @MainActor () -> Bool = { true }) {
        self.suspendreEnArrierePlan = suspendreEnArrierePlan
    }

    public var body: some View {
        TabView(selection: $onglet) {
            Tab(Onglet.sessions.libelle, systemImage: Onglet.sessions.symbole, value: .sessions) {
                DiscussionEcran()
            }
            Tab(Onglet.modeles.libelle, systemImage: Onglet.modeles.symbole, value: .modeles) {
                MachineEcran(rayon: .modeles)
            }
            Tab(Onglet.systeme.libelle, systemImage: Onglet.systeme.symbole, value: .systeme) {
                MachineEcran(rayon: .systeme)
            }
        }
        .tint(Teinte.accent)
        .environment(salon)
        .ambiance(Ambiance())
        // Pas `preferredColorScheme` : il réglerait toute la fenêtre, donc les autres mondes du pupitre.
        .environment(\.colorScheme, theme.schema)
        .sensoryFeedback(Retour.bascule, trigger: onglet)
        .overlay { voileTour }
        .task {
            await salon.demarrer()
            let suivi = SuiviTour(client: salon.client)
            tour = suivi
            suivi.suivre()
        }
        .task(id: phase == .active) { await sonderLeMoteur() }
        // Monde quitté : plus de flux ni de sonde. Le PC poursuit la génération, le retour la relit.
        .onDisappear {
            salon.suspendre()
            tour?.arreter()
        }
        .onChange(of: phase) { _, nouvelle in reagir(nouvelle) }
    }

    /// La pastille dit l'état réel : relevé toutes les 5 s au premier plan, comme l'en-tête du web.
    private func sonderLeMoteur() async {
        guard phase == .active else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { await salon.rafraichirStatut() }
        }
    }

    /// Tant que la tour n'est pas prête, rien d'autre n'a de sens : l'écran d'état couvre l'app.
    @ViewBuilder private var voileTour: some View {
        if let tour, !Self.estPrete(tour.phase) {
            TourEcran(suivi: tour).transition(.opacity)
        }
    }

    private static func estPrete(_ phase: PhaseTour?) -> Bool {
        if case .prete = phase { return true }
        return false
    }

    /// `☠` Le seul crochet qui rende l'app honnête au réveil. Sans lui, le
    /// statut n'était JAMAIS re-sondé : Chris allumait son PC et l'app
    /// continuait d'affirmer qu'il était éteint jusqu'à ce qu'il aille tirer
    /// l'onglet Machine vers le bas — et symétriquement, elle le disait prêt
    /// après extinction, ce qui autorise un envoi qui échouera.
    ///
    /// Seul `.background` suspend : `.inactive` arrive à chaque bandeau de
    /// notification, et couper une génération pour ça serait pire que le mal.
    private func reagir(_ nouvelle: ScenePhase) {
        switch nouvelle {
        case .background: if suspendreEnArrierePlan() { salon.suspendre() }
        case .active:
            Task { await salon.reprendre() }
            tour?.suivre()
        default: break
        }
    }
}

/// Les trois onglets de l'EchoHub web, dans son ordre.
public enum Onglet: String, Hashable, CaseIterable {
    case sessions, modeles, systeme

    public var libelle: String {
        switch self {
        case .sessions: return "Sessions"
        case .modeles: return "Modèles"
        case .systeme: return "Système"
        }
    }

    public var symbole: String {
        switch self {
        case .sessions: return "bubble.left.and.bubble.right"
        case .modeles: return "square.stack.3d.up"
        case .systeme: return "cpu"
        }
    }
}
#endif
