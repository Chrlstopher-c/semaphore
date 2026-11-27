// L'aperçu de l'app que l'agent fait tourner, par le relais du Pi : la première requête porte le jeton,
// le relais répond par un cookie signé et sert ensuite l'app (WebSocket compris), en 4G comme au Wi-Fi.
#if canImport(SwiftUI) && canImport(WebKit)
import SwiftUI
import WebKit
import EchoHubNoyau

struct ApercuWeb: UIViewRepresentable {
    let requete: URLRequest
    let rechargement: Int

    func makeUIView(context: Context) -> WKWebView {
        let vue = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        vue.allowsBackForwardNavigationGestures = true
        vue.load(requete)
        context.coordinator.rechargement = rechargement
        return vue
    }

    func updateUIView(_ vue: WKWebView, context: Context) {
        guard context.coordinator.rechargement != rechargement else { return }
        context.coordinator.rechargement = rechargement
        vue.reload()
    }

    func makeCoordinator() -> Coordinateur { Coordinateur() }

    final class Coordinateur { var rechargement = 0 }
}

/// La feuille plein écran de l'aperçu, avec Recharger.
struct ApercuFeuille: View {
    let requete: URLRequest
    @Environment(\.dismiss) private var fermer
    @State private var rechargement = 0

    var body: some View {
        NavigationStack {
            ApercuWeb(requete: requete, rechargement: rechargement)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Aperçu")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Fermer") { fermer() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { rechargement += 1 } label: { Image(systemName: "arrow.clockwise") }
                            .accessibilityLabel("Recharger")
                    }
                }
        }
    }
}
#endif
