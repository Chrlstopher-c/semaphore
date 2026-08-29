// La coquille du monde Movix : deux onglets — le site dans une WebView, et le
// réglage de l'adresse. Le point de couplage public unique avec le pupitre
// (`Movix.Coquille()`), comme les autres mondes.
#if canImport(SwiftUI)
import SwiftUI

public struct Coquille: View {
    @State private var modele = ModeleMovix()
    @State private var onglet: Onglet = .movix

    public init() {}

    public var body: some View {
        TabView(selection: $onglet) {
            Tab(Onglet.movix.libelle, systemImage: Onglet.movix.symbole, value: .movix) {
                VueMovix()
            }
            Tab(Onglet.reglages.libelle, systemImage: Onglet.reglages.symbole, value: .reglages) {
                ReglagesEcran()
            }
        }
        .tint(Teinte.accent)
        .environment(modele)
        .preferredColorScheme(.dark)
    }
}

/// L'onglet principal : la WebView si l'adresse est valide, sinon une invite à
/// aller la corriger dans les réglages.
private struct VueMovix: View {
    @Environment(ModeleMovix.self) private var modele

    var body: some View {
        ZStack {
            Teinte.fond.ignoresSafeArea()
            if let url = modele.url {
                VueWeb(url: url).ignoresSafeArea(edges: .bottom)
            } else {
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
