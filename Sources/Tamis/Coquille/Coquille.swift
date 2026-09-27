// La coquille du monde Tamis : quatre onglets, et rien d'autre. Elle tient
// l'atelier et ne démarre qu'à la première visite du monde — sinon la demande
// d'accès aux photos surgirait au lancement d'Echo, au milieu du Quart.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme

public struct Coquille: View {
    /// Vrai quand le pupitre montre ce monde.
    private let visible: Bool
    @Environment(\.scenePhase) private var phase
    @State private var atelier = Atelier()
    @State private var onglet: Onglet = .strates

    public init(visible: Bool) {
        self.visible = visible
    }

    public var body: some View {
        TabView(selection: $onglet) {
            Tab(Onglet.strates.libelle, systemImage: Onglet.strates.symbole, value: .strates) {
                StratesEcran()
            }
            Tab(Onglet.tri.libelle, systemImage: Onglet.tri.symbole, value: .tri) {
                TriEcran()
            }
            Tab(Onglet.pistes.libelle, systemImage: Onglet.pistes.symbole, value: .pistes) {
                PistesEcran()
            }
            Tab(Onglet.panier.libelle, systemImage: Onglet.panier.symbole, value: .panier) {
                PanierEcran()
            }
            .badge(atelier.decisions.panier.count)
        }
        .tint(Teinte.accent)
        .environment(atelier)
        .preferredColorScheme(.dark)
        .sensoryFeedback(Toucher.selection, trigger: onglet)
        .overlay { AccesEcran() }
        .task(id: visible) { if visible { await atelier.demarrer() } }
        .onChange(of: phase) { _, nouvelle in reagir(nouvelle) }
    }
}

extension Coquille {
    /// `.inactive` (centre de contrôle, bandeau) ne suspend rien.
    private func reagir(_ nouvelle: ScenePhase) {
        switch nouvelle {
        case .background:
            atelier.sommeil()
        case .active:
            atelier.reveil()
            guard visible else { return }
            Task {
                if atelier.etat == .pret { await atelier.actualiser() } else { await atelier.demarrer() }
            }
        default:
            break
        }
    }
}

enum Onglet: Hashable, CaseIterable {
    case strates, tri, pistes, panier

    var libelle: String {
        switch self {
        case .strates: return "Strates"
        case .tri: return "Tri"
        case .pistes: return "Pistes"
        case .panier: return "Panier"
        }
    }

    var symbole: String {
        switch self {
        case .strates: return "square.stack.3d.down.right"
        case .tri: return "hand.draw"
        case .pistes: return "sparkle.magnifyingglass"
        case .panier: return "trash"
        }
    }
}

/// Ce qui recouvre le monde tant qu'il n'a rien à montrer : accès refusé, ou
/// inventaire en cours. Transparent le reste du temps.
struct AccesEcran: View {
    @Environment(Atelier.self) private var atelier
    @Environment(\.openURL) private var ouvrir

    var body: some View {
        switch atelier.etat {
        case .refuse:
            voile {
                EtatCalme(
                    symbole: "photo.badge.exclamationmark",
                    titre: "Tamis n'a pas accès aux photos",
                    detail: "Réglages › Echo › Photos › Accès complet. Rien ne quitte le téléphone."
                ) {
                    Button("Ouvrir les réglages") {
                        if let url = URL(string: "app-settings:") { ouvrir(url) }
                    }
                    .buttonStyle(.engage)
                }
            }
        case .attente, .inventaire:
            voile {
                EtatCalme(symbole: "square.stack.3d.down.right", titre: "Inventaire…",
                          detail: "Tamis lit la photothèque. Quelques secondes.")
            }
        case .pret:
            EmptyView()
        }
    }

    private func voile(@ViewBuilder _ contenu: () -> some View) -> some View {
        ZStack {
            Neutre.fond.ignoresSafeArea()
            contenu()
        }
        .transition(.opacity)
    }
}
#endif
