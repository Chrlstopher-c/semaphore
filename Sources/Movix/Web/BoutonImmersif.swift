// Le bouton plein écran, en UIKit natif — et non un bouton SwiftUI posé en
// overlay.
//
// `☠` Un contrôle SwiftUI superposé à une `WKWebView` ne reçoit PAS ses touches
// de façon fiable : les gesture recognizers internes de la WebView les captent
// d'abord, et le tap « traverse » vers la page. La parade déterministe est une
// UIView qui couvre l'écran mais dont `hitTest` ne retient QUE le disque du
// bouton — partout ailleurs il rend `nil`, laissant le touch filer à la WebView
// dessous. Le bouton, lui, est un vrai `UIButton` au-dessus de la WebView dans
// la hiérarchie : son touch ne redescend jamais à la page.
#if canImport(UIKit)
import SwiftUI
import UIKit

struct BoutonImmersif: UIViewRepresentable {
    let immersif: Bool
    let estompe: Bool
    let action: () -> Void

    private static let cote: CGFloat = 46
    private static let accent = UIColor(red: 0xE8 / 255, green: 0x47 / 255, blue: 0x7C / 255, alpha: 0.9)

    func makeCoordinator() -> Coordinateur { Coordinateur(action: action) }

    func makeUIView(context: Context) -> UIView {
        let couche = CoucheTraversante()
        couche.backgroundColor = .clear

        let bouton = UIButton(type: .system)
        bouton.translatesAutoresizingMaskIntoConstraints = false
        bouton.tintColor = .white
        bouton.backgroundColor = UIColor.black.withAlphaComponent(0.62)
        bouton.layer.cornerRadius = Self.cote / 2
        bouton.layer.borderWidth = 1.5
        bouton.layer.borderColor = Self.accent.cgColor
        bouton.addTarget(context.coordinator, action: #selector(Coordinateur.tape), for: .touchUpInside)

        couche.addSubview(bouton)
        NSLayoutConstraint.activate([
            bouton.centerXAnchor.constraint(equalTo: couche.centerXAnchor),
            bouton.topAnchor.constraint(equalTo: couche.safeAreaLayoutGuide.topAnchor, constant: 8),
            bouton.widthAnchor.constraint(equalToConstant: Self.cote),
            bouton.heightAnchor.constraint(equalToConstant: Self.cote),
        ])

        context.coordinator.bouton = bouton
        appliquer(bouton)
        return couche
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.action = action
        if let bouton = context.coordinator.bouton { appliquer(bouton) }
    }

    private func appliquer(_ bouton: UIButton) {
        let nom = immersif ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        bouton.setImage(UIImage(systemName: nom, withConfiguration: config), for: .normal)
        bouton.alpha = estompe ? 0.28 : 1
    }

    final class Coordinateur: NSObject {
        var action: () -> Void
        weak var bouton: UIButton?

        init(action: @escaping () -> Void) { self.action = action }

        @objc func tape() { action() }
    }
}

/// Couvre tout l'espace mais ne « prend » le touch que sur ses sous-vues (le
/// bouton). Ailleurs, `nil` → le touch descend à la WebView.
private final class CoucheTraversante: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let touche = super.hitTest(point, with: event)
        return touche === self ? nil : touche
    }
}
#endif
