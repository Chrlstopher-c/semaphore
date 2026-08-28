// La coquille : trois onglets, et rien d'autre. Elle ne contient aucune donnée
// et aucune règle de forme — elle pose l'ambiance racine, tient le salon, et
// laisse chaque pièce décider du reste.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

public struct Coquille: View {
    @Environment(\.scenePhase) private var phase
    @State private var salon = Salon()
    @State private var onglet: Onglet = .fil
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
            Tab(Onglet.fil.libelle, systemImage: Onglet.fil.symbole, value: .fil) {
                DiscussionEcran()
            }
            Tab(
                Onglet.conversations.libelle,
                systemImage: Onglet.conversations.symbole,
                value: .conversations
            ) {
                ConversationsEcran(surOuverture: { onglet = .fil })
            }
            Tab(Onglet.machine.libelle, systemImage: Onglet.machine.symbole, value: .machine) {
                MachineEcran()
            }
        }
        .tint(Teinte.accent)
        .environment(salon)
        .ambiance(Ambiance())
        .preferredColorScheme(.dark)
        .sensoryFeedback(Retour.bascule, trigger: onglet)
        .task { await salon.demarrer() }
        .onChange(of: phase) { _, nouvelle in reagir(nouvelle) }
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
        case .active: Task { await salon.reprendre() }
        default: break
        }
    }
}

/// Trois onglets, pas cinq : l'app en fait trois choses. Un onglet qu'on ouvre
/// une fois par mois vole un tiers de la barre.
public enum Onglet: String, Hashable, CaseIterable {
    case fil, conversations, machine

    public var libelle: String {
        switch self {
        case .fil: return "Fil"
        case .conversations: return "Conversations"
        case .machine: return "Machine"
        }
    }

    public var symbole: String {
        switch self {
        case .fil: return "text.alignleft"
        case .conversations: return "bubble.left.and.bubble.right"
        case .machine: return "cpu"
        }
    }
}
#endif
