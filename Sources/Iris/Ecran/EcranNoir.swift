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
    @State private var noir = false
    @State private var mention = true
    @State private var luminosite: CGFloat?
    @State private var minuterie: Task<Void, Never>?

    private static let delai: Duration = .seconds(10)
    private static let dureeMention: Duration = .seconds(3)

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(TapGesture().onEnded { armer() })
            .onChange(of: actif, initial: true) { _, enDirect in enDirect ? armer() : reveiller(rearmer: false) }
            .onChange(of: reglages) { _, _ in armer() }
            .onDisappear { reveiller(rearmer: false) }
            .fullScreenCover(isPresented: $noir) { voile }
    }

    private var voile: some View {
        Color.black
            .ignoresSafeArea()
            .overlay {
                Text("Iris en direct · touchez pour rallumer")
                    .font(.footnote).foregroundStyle(.white.opacity(0.35))
                    .opacity(mention ? 1 : 0)
                    .animation(.easeOut(duration: 0.8), value: mention)
            }
            .contentShape(Rectangle())
            .onTapGesture { reveiller(rearmer: true) }
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .presentationBackground(.black)
            .task {
                mention = true
                try? await Task.sleep(for: Self.dureeMention)
                mention = false
            }
    }

    private static var ecran: UIScreen? {
        (UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene)?.screen
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
        guard !noir, let ecran = Self.ecran else { return }
        luminosite = ecran.brightness
        ecran.brightness = 0
        sansAnimation { noir = true }
    }

    private func reveiller(rearmer: Bool) {
        minuterie?.cancel()
        if let luminosite, let ecran = Self.ecran { ecran.brightness = luminosite }
        luminosite = nil
        if noir { sansAnimation { noir = false } }
        if rearmer { armer() }
    }

    private func sansAnimation(_ changement: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, changement)
    }
}
#endif
