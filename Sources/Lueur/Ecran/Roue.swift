// La roue chromatique, focal du monde : teinte à l'angle, saturation au rayon, interrupteur au cœur.
// Rendu exact sans shader : un dégradé angulaire des teintes pures, voilé d'un dégradé radial blanc → transparent
// (blanc × (1 − s) + teinte × s est précisément le HSV à v = 1 — la roue ne ment pas sur ce qui part au ruban).
#if canImport(SwiftUI) && canImport(UIKit)
import LueurNoyau
import SwiftUI
import Systeme

struct RoueChromatique: View {
    @Environment(Lampe.self) private var lampe
    private let rayon = Trame.roue / 2
    /// Les six primaires et secondaires exactes, rebouclées : ce que le ruban recevra, pas les teintes adoucies d'iOS.
    private static let teintes = stride(from: 0.0, through: 360, by: 60)
        .map { Color(nuance: Nuance(teinte: $0, saturation: 1)) }

    var body: some View {
        ZStack {
            halo
            disque
                .gesture(DragGesture(minimumDistance: 0).onChanged(choisir))
                .opacity(allume ? 1 : 0.3)
            curseur
            Interrupteur()
        }
        .frame(width: Trame.roue, height: Trame.roue)
        .animation(Mouvement.normal, value: allume)
    }

    private var allume: Bool { lampe.etat?.allume ?? false }
    private var vivante: Color { lampe.couleur.map(Color.init(nuance:)) ?? Neutre.encreEteinte }

    private var halo: some View {
        Circle()
            .fill(vivante.opacity(0.2))
            .blur(radius: Trame.halo)
            .opacity(allume ? 1 : 0)
    }

    private var disque: some View {
        Circle()
            .fill(AngularGradient(colors: Self.teintes, center: .center))
            .overlay(Circle().fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center,
                                                  startRadius: 0, endRadius: rayon)))
            .overlay(Circle().strokeBorder(Neutre.trait, lineWidth: Grille.trait))
            .contentShape(Circle())
    }

    @ViewBuilder private var curseur: some View {
        if let couleur = lampe.couleur {
            let point = Roue.position(de: couleur, rayon: rayon)
            Circle()
                .fill(Color(nuance: couleur))
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .frame(width: Trame.curseur, height: Trame.curseur)
                .offset(x: point.dx, y: point.dy)
                .opacity(allume ? 1 : 0)
                .allowsHitTesting(false)
        }
    }

    private func choisir(_ geste: DragGesture.Value) {
        let nuance = Roue.nuance(dx: geste.location.x - rayon, dy: geste.location.y - rayon, rayon: rayon)
        guard nuance != lampe.apercu else { return }
        lampe.envoyer(.couleur(nuance))
    }
}

/// Allumer, éteindre : le seul geste que tout le monde fait. Glyphe dans la couleur vivante, éteint en neutre.
private struct Interrupteur: View {
    @Environment(Lampe.self) private var lampe

    var body: some View {
        let allume = lampe.etat?.allume ?? false
        let vivante = lampe.couleur.map(Color.init(nuance:)) ?? Neutre.encre
        Button {
            lampe.envoyer(.allumer(!allume))
        } label: {
            Image(systemName: "power")
                .font(Voix.titreSection)
                .foregroundStyle(allume ? vivante : Neutre.encreEteinte)
                .frame(width: Trame.interrupteur, height: Trame.interrupteur)
                .background(Circle().fill(Neutre.fond.opacity(0.85)))
                .overlay(Circle().strokeBorder(Neutre.lumiereHaute, lineWidth: Grille.trait))
                .contentShape(Circle())
        }
        .buttonStyle(Presse())
        .accessibilityLabel(allume ? "Éteindre" : "Allumer")
        .sensoryFeedback(Toucher.engage, trigger: allume)
    }
}

/// Press state universel : 0,97 sur `Mouvement.micro`.
struct Presse: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Mouvement.micro, value: configuration.isPressed)
    }
}

extension Color {
    init(nuance: Nuance) {
        self.init(.sRGB, red: Double(nuance.rouge) / 255, green: Double(nuance.vert) / 255,
                  blue: Double(nuance.bleu) / 255)
    }
}
#endif
