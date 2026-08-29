// La WebView du monde Movix : une WKWebView plein écran qui charge l'instance
// Movix configurée. Contrairement au rendu d'artefact isolé de Vigie, ici la
// navigation est LIBRE (liens internes, players, changement d'épisode) et le
// magasin est PERSISTANT — Movix garde sa session et son localStorage entre
// deux ouvertures.
#if canImport(SwiftUI)
import SwiftUI
import WebKit

struct VueWeb: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinateur { Coordinateur() }

    func makeUIView(context: Context) -> WKWebView {
        let reglage = WKWebViewConfiguration()
        reglage.allowsInlineMediaPlayback = true
        reglage.mediaTypesRequiringUserActionForPlayback = []
        let vue = WKWebView(frame: .zero, configuration: reglage)
        vue.allowsBackForwardNavigationGestures = true
        vue.isOpaque = false
        vue.backgroundColor = .black
        vue.scrollView.backgroundColor = .black
        vue.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.derniereChargee = url
        vue.load(URLRequest(url: url))
        return vue
    }

    /// Recharge uniquement quand l'adresse CIBLE change (réglage modifié) —
    /// jamais sur une simple redirection interne du site, sinon toute navigation
    /// relancerait la page d'accueil.
    func updateUIView(_ vue: WKWebView, context: Context) {
        guard context.coordinator.derniereChargee != url else { return }
        context.coordinator.derniereChargee = url
        vue.load(URLRequest(url: url))
    }

    final class Coordinateur {
        var derniereChargee: URL?
    }
}
#endif
