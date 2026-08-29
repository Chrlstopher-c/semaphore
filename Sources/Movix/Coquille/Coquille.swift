// La coquille du monde Movix : deux onglets — le site dans une WebView, et le
// réglage de l'adresse. Un mode PLEIN ÉCRAN (piloté par un bouton HUD auto-hide,
// au centre en haut) masque le chrome d'Echo — le sélecteur de mondes en haut
// (via `immersif`, lu par le pupitre) et la barre d'onglets en bas — pour rendre
// tout l'écran au player web, dont les contrôles vivent aux mêmes bords.
#if canImport(SwiftUI)
import SwiftUI

public struct Coquille: View {
    @Binding var immersif: Bool
    @State private var modele = ModeleMovix()
    @State private var onglet: Onglet = .movix

    public init(immersif: Binding<Bool>) {
        self._immersif = immersif
    }

    public var body: some View {
        TabView(selection: $onglet) {
            Tab(Onglet.movix.libelle, systemImage: Onglet.movix.symbole, value: .movix) {
                VueMovix(immersif: $immersif)
            }
            Tab(Onglet.reglages.libelle, systemImage: Onglet.reglages.symbole, value: .reglages) {
                ReglagesEcran()
            }
        }
        .tint(Teinte.accent)
        .environment(modele)
        .preferredColorScheme(.dark)
        // En plein écran, la barre d'onglets du bas s'efface : le player web
        // récupère ce bord. On en sort par le bouton HUD.
        .toolbar(immersif ? .hidden : .automatic, for: .tabBar)
    }
}

/// L'onglet principal : la WebView (plein écran en mode immersif), surmontée d'un
/// bouton HUD centré en haut qui bascule le plein écran et s'estompe tout seul.
private struct VueMovix: View {
    @Environment(ModeleMovix.self) private var modele
    @Binding var immersif: Bool
    @State private var hudEstompe = false
    @State private var tacheEstompe: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
            Teinte.fond.ignoresSafeArea()
            if let url = modele.url {
                VueWeb(url: url)
                    .ignoresSafeArea(edges: immersif ? .all : .bottom)
            } else {
                invite
            }
        }
        // Le bouton est en UIKit natif (voir BoutonImmersif) : posé en overlay
        // SwiftUI, il ne recevrait pas ses touches par-dessus la WebView. La
        // couche remplit l'écran mais ne capte que le disque du bouton ; partout
        // ailleurs le touch file au player.
        .overlay {
            if modele.url != nil {
                BoutonImmersif(immersif: immersif, estompe: hudEstompe) {
                    withAnimation(.easeInOut(duration: 0.25)) { immersif.toggle() }
                    reveler()
                }
            }
        }
        .onAppear { reveler() }
    }

    private var invite: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(Teinte.encreDouce)
            Text("Adresse Movix invalide")
                .font(.headline)
                .foregroundStyle(Teinte.encre)
            Text("Corrige-la dans l'onglet Réglages.")
                .font(.subheadline)
                .foregroundStyle(Teinte.encreDouce)
        }
        .padding()
    }

    private func reveler() {
        tacheEstompe?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { hudEstompe = false }
        tacheEstompe = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { hudEstompe = true }
        }
    }
}

public enum Onglet: String, Hashable, CaseIterable {
    case movix, reglages

    public var libelle: String {
        switch self {
        case .movix: return "Movix"
        case .reglages: return "Réglages"
        }
    }

    public var symbole: String {
        switch self {
        case .movix: return "play.rectangle.fill"
        case .reglages: return "slider.horizontal.3"
        }
    }
}
#endif
