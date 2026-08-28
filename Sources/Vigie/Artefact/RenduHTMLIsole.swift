// Rendu HTML d'un artefact — CONTENU NON FIABLE produit par un modèle.
//
// `☠` Équivalent iOS de l'`<iframe sandbox="allow-scripts">` SANS
// `allow-same-origin` utilisé côté web (`harness-artefacts.js`) : les scripts
// de l'artefact s'exécutent, mais ne peuvent ni lire la session de Chris, ni
// aller nulle part. WKWebView n'a pas d'attribut `sandbox` : la garantie tient
// sur trois mécanismes, posés ici et documentés à leur emploi :
//
// 1. `websiteDataStore = .nonPersistent()` — magasin éphémère, propre à cette
//    seule vue, jamais écrit sur le disque de l'app, jamais partagé avec un
//    autre chargement. Filet de sécurité : le jeton de session de Vigie ne vit
//    de toute façon dans AUCUN `WKWebsiteDataStore` — `ClientPi` le range en
//    Keychain et le pose à la main en en-tête `Cookie:` sur ses requêtes
//    `URLSession`, jamais via `WKHTTPCookieStore` — donc même une fuite de
//    magasin n'y trouverait rien à lire.
// 2. `loadHTMLString(_:baseURL: nil)` — origine OPAQUE, l'exact équivalent de
//    l'absence d'`allow-same-origin` : `document.cookie`, `localStorage`,
//    tout stockage scopé à une origine réelle sont hors de portée du script.
// 3. Navigation refusée en bloc dans `Coordinateur` : seule la charge posée
//    par `loadHTMLString` lui-même est admise. Un clic de lien, un
//    `window.location` ou un `window.open` depuis le script de l'artefact ne
//    mène nulle part — ni vers le web, ni vers une route de Vigie.
//
// Non éprouvé sur l'appareil (pas de simulateur sur cette chaîne) : à
// confirmer par Chris, comme le rendu visuel de toute la carte.
#if canImport(SwiftUI)
import SwiftUI
import WebKit

struct RenduHTMLIsole: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinateur { Coordinateur() }

    func makeUIView(context: Context) -> WKWebView {
        let reglage = WKWebViewConfiguration()
        reglage.websiteDataStore = .nonPersistent()
        reglage.preferences.javaScriptCanOpenWindowsAutomatically = false
        let vue = WKWebView(frame: .zero, configuration: reglage)
        vue.navigationDelegate = context.coordinator
        vue.uiDelegate = context.coordinator
        vue.allowsLinkPreview = false
        vue.allowsBackForwardNavigationGestures = false
        vue.scrollView.bounces = false
        vue.isOpaque = false
        vue.backgroundColor = .white
        vue.loadHTMLString(html, baseURL: nil)
        return vue
    }

    /// Un artefact ne se réédite jamais (mandat serveur : pas de version, pas
    /// d'édition) — `html` ne change pas la vie de cette vue, rien à recharger.
    func updateUIView(_ vue: WKWebView, context: Context) {}

    /// `☠` Refuse toute navigation hors du tout premier chargement. Un artefact
    /// n'a AUCUNE destination légitime hors du document qu'il est déjà : ni un
    /// lien cliqué, ni une redirection JS, ni une soumission de formulaire.
    final class Coordinateur: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var chargementInitialFait = false

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .other, !chargementInitialFait else {
                decisionHandler(.cancel)
                return
            }
            chargementInitialFait = true
            decisionHandler(.allow)
        }

        /// `window.open` depuis le script de l'artefact : aucune fenêtre neuve.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? { nil }
    }
}
#endif
