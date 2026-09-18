// L'anneau : le seul grand objet du monde. Au repos il est le bouton Écouter ;
// en écoute il est le témoin que le son coule, et le geste pour l'arrêter. Le
// même objet porte les deux états, donc le passage à l'écoute est une
// transformation de ce qu'on regarde déjà — pas un remplacement d'écran.
//
// `☠` En écoute, l'anneau RESPIRE : opacité seule, quatre secondes, aucune
// mise en page. C'est un écran regardé une heure durant — rien ne doit
// clignoter. Sous « Réduire les animations », il reste allumé, fixe.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

struct AnneauEcoute: View {
    enum Regime: Hashable {
        /// Relié, silencieux : l'anneau est un bouton.
        case silencieux
        /// L'écoute est lancée mais le tampon n'a pas encore atteint la cible.
        case amorcage
        /// Le son coule.
        case ecoute
    }

    let regime: Regime
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduireMouvement
    @State private var inspire = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(fond)
                Circle()
                    .strokeBorder(trait, lineWidth: Trame.traitAnneau)
                    .opacity(opaciteSouffle)
                Image(systemName: glyphe)
                    .font(.system(.largeTitle, weight: .light))
                    .foregroundStyle(encreGlyphe)
                    .opacity(opaciteSouffle)
            }
            .frame(width: Trame.anneau, height: Trame.anneau)
            .contentShape(Circle())
        }
        .buttonStyle(.appui)
        .animation(Mouvement.surface, value: regime)
        .onChange(of: regime, initial: true) { _, nouveau in respirer(nouveau) }
        .accessibilityLabel(libelle)
    }

    // MARK: - Peinture selon le régime

    private var fond: Color {
        regime == .ecoute ? Ton.actif.voile : Neutre.surface
    }

    private var trait: Color {
        switch regime {
        case .silencieux: return Neutre.lumiereHaute
        case .amorcage: return Neutre.encreEteinte
        case .ecoute: return Teinte.accent
        }
    }

    private var encreGlyphe: Color {
        switch regime {
        case .silencieux, .ecoute: return Teinte.accent
        case .amorcage: return Neutre.encreDouce
        }
    }

    private var glyphe: String {
        regime == .silencieux ? "play.fill" : "waveform"
    }

    private var libelle: String {
        switch regime {
        case .silencieux: return "Écouter"
        case .amorcage: return "Mise en tampon, toucher pour arrêter"
        case .ecoute: return "En écoute, toucher pour arrêter"
        }
    }

    // MARK: - Le souffle

    private var opaciteSouffle: Double {
        guard regime == .ecoute, !reduireMouvement else { return 1 }
        return inspire ? 1 : 0.45
    }

    private func respirer(_ regime: Regime) {
        guard regime == .ecoute, !reduireMouvement else {
            withAnimation(Mouvement.normal) { inspire = false }
            return
        }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            inspire = true
        }
    }
}
#endif
