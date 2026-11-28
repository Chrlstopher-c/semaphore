// L'écran noir de la diffusion. iOS coupe la caméra d'une appli dès que l'iPhone se verrouille : l'écran reste donc
// allumé, mais tout noir (pixels OLED éteints) et à luminosité minimale, après quelques secondes sans toucher.
// Un toucher le rallume et rend la luminosité d'avant.
#if canImport(SwiftUI) && canImport(UIKit)
import IrisNoyau
import SwiftUI
import UIKit

struct EcranNoir: ViewModifier {
    let actif: Bool
    let reglages: Reglages
    @State private var luminosite: CGFloat?
    @State private var minuterie: Task<Void, Never>?

    private static let delai: Duration = .seconds(10)

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(TapGesture().onEnded { armer() })
            .onChange(of: actif, initial: true) { _, enDirect in enDirect ? armer() : reveiller(rearmer: false) }
            .onChange(of: reglages) { _, _ in armer() }
            .onDisappear { reveiller(rearmer: false) }
    }

    private func armer() {
        minuterie?.cancel()
        guard actif else { return }
        minuterie = Task { @MainActor in
            try? await Task.sleep(for: Self.delai)
            guard !Task.isCancelled, actif else { return }
            assombrir()
        }
    }

    private func assombrir() {
        guard !Voile.present, let scene = Voile.scene else { return }
        luminosite = scene.screen.brightness
        scene.screen.brightness = 0
        Voile.montrer(dans: scene) { reveiller(rearmer: true) }
    }

    private func reveiller(rearmer: Bool) {
        minuterie?.cancel()
        if let luminosite, let scene = Voile.scene { scene.screen.brightness = luminosite }
        luminosite = nil
        Voile.cacher()
        if rearmer { armer() }
    }
}

/// Le voile noir vit dans sa propre fenêtre, au-dessus de la barre d'état : présenté en plein écran SwiftUI, il
/// retirait la vue d'Iris de l'écran (`onDisappear`), ce qui coupait la diffusion au bout des 10 s.
@MainActor
private enum Voile {
    private static var fenetre: UIWindow?
    static var present: Bool { fenetre != nil }
    static var scene: UIWindowScene? {
        UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene
    }

    static func montrer(dans scene: UIWindowScene, toucher: @escaping () -> Void) {
        let f = UIWindow(windowScene: scene)
        f.windowLevel = .statusBar + 1
        f.rootViewController = HoteVoile(rootView: VueVoile(toucher: toucher))
        f.isHidden = false
        fenetre = f
    }

    static func cacher() {
        fenetre?.isHidden = true
        fenetre = nil
    }
}

private final class HoteVoile: UIHostingController<VueVoile> {
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
}

private struct VueVoile: View {
    let toucher: () -> Void
    @State private var mention = true

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay {
                Text("Iris en direct · touchez pour rallumer")
                    .font(.footnote).foregroundStyle(.white.opacity(0.35))
                    .opacity(mention ? 1 : 0)
                    .animation(.easeOut(duration: 0.8), value: mention)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: toucher)
            .task {
                try? await Task.sleep(for: .seconds(3))
                mention = false
            }
    }
}
#endif
