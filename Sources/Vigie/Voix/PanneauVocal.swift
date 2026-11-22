// Responsabilité : ce que Chris voit du mode vocal — le bouton rond qui l'ouvre, à droite du champ (comme l'appli
// Claude iOS), et le panneau qui remplace le composeur tant qu'il est ouvert : état, ce qu'il dit, la phrase que
// Claude dit, « Passer » et « Terminer ».
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Le bouton du mode vocal, hors du champ de saisie.
struct BoutonVocal: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "waveform").font(.system(size: 19, weight: .semibold)).foregroundStyle(Q.texte)
                .frame(width: 52, height: 52).background(Q.carte, in: .circle)
        }
        .buttonStyle(StyleAppui())
        .accessibilityLabel("Mode vocal")
    }
}

struct PanneauVocal: View {
    @State private var mode = ModeVocal.partage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Indicateur(etat: mode.etat)
                Text(libelle).font(Q.detail).foregroundStyle(Q.secondaire)
                Spacer(minLength: 0)
                if !mode.voixTour && mode.phraseLue != nil {
                    Text("voix de l’iPhone").font(Q.detail).foregroundStyle(Q.tertiaire)
                }
            }
            Text(texte).font(Q.rangee).foregroundStyle(mode.entendu.isEmpty ? Q.secondaire : Q.texte)
                .lineLimit(3).frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                .contentTransition(.interpolate)
                .animation(.easeOut(duration: 0.2), value: texte)
            HStack(spacing: 10) {
                Bouton(titre: "Passer", icone: "forward.end.fill", actif: mode.etat == .parle) { mode.passer() }
                Spacer(minLength: 0)
                Bouton(titre: "Terminer", icone: "xmark", actif: true) { mode.sortir() }
            }
        }
        .padding(16)
        .background(Q.carte, in: .rect(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 8).padding(.vertical, 8)
        .background(Color(hex: 0x232323).ignoresSafeArea(edges: .bottom))
        .sensoryFeedback(.impact(weight: .light), trigger: mode.etat)
    }

    private var libelle: String {
        switch mode.etat {
        case .ecoute: return "Je t’écoute"
        case .envoi: return "Envoi…"
        case .attente: return "Claude réfléchit…"
        case .parle: return "Claude parle — parle pour le couper"
        }
    }

    private var texte: String {
        if !mode.entendu.isEmpty { return mode.entendu }
        if let phrase = mode.phraseLue { return phrase }
        return mode.etat == .ecoute ? "Parle, j’envoie après un silence." : " "
    }
}

private struct Indicateur: View {
    let etat: ModeVocal.Etat

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(etat == .parle ? Q.texte : Q.coche).frame(width: 3, height: 16)
                    .phaseAnimator([0.3, 1.0]) { vue, phase in vue.scaleEffect(y: phase, anchor: .center) }
                        animation: { _ in .easeInOut(duration: etat == .attente ? 0.8 : 0.4).delay(Double(i) * 0.12) }
            }
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}

private struct Bouton: View {
    let titre: String
    let icone: String
    let actif: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(titre, systemImage: icone).font(Q.rangee).foregroundStyle(actif ? Q.texte : Q.tertiaire)
                .padding(.horizontal, 16).frame(height: 40).background(Q.rond, in: .capsule)
        }
        .buttonStyle(StyleAppui())
        .disabled(!actif)
    }
}
#endif
