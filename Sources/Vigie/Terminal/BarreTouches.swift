// La barre de touches du terminal : ce que le clavier iOS n'a pas et dont un
// shell ne peut pas se passer — Esc, Tab, flèches, et le modificateur Ctrl.
//
// `☠` CONTRAINTE DE LA ROUTE (`ToucheTerminal`) : le serveur ajoute TOUJOURS
// Entrée 200 ms après les octets. Chaque touche valide donc ce qu'elle fait —
// l'info-bulle d'accessibilité porte l'effet réel.
//
// `☠` Les séquences qui TUENT (^C, ^D) sont derrière un maintien armé : sur
// un écran tenu d'une main, un ^C parti tout seul coupe un processus réel.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct BarreTouches: View {
    let ctrlArme: Bool
    let basculerCtrl: @MainActor () -> Void
    let envoyer: @MainActor (String) async -> Void

    var body: some View {
        VStack(spacing: 0) {
            if ctrlArme {
                RangeeControleArme(annuler: basculerCtrl, envoyer: envoyer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            rangeePrincipale
        }
        .animation(Elan.pose, value: ctrlArme)
    }

    private var rangeePrincipale: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Trame.serre) {
                ForEach(ToucheTerminal.toutes) { touche in
                    boutonTouche(touche)
                }
                Spacer(minLength: 0)
                Button {
                    ClavierQuart.fermer()
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Teinte.encreDouce)
                        .frame(minWidth: 40, minHeight: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer le clavier")
            }
            .padding(.horizontal, Trame.ecran)
        }
        .scrollIndicators(.hidden)
        .frame(height: 46)
        .background(Teinte.fondCreux)
        .overlay(alignment: .top) { FiletFin() }
    }

    private func boutonTouche(_ touche: ToucheTerminal) -> some View {
        Button {
            if touche.estModificateur {
                basculerCtrl()
            } else {
                Task { await envoyer(touche.sequence) }
            }
        } label: {
            Text(touche.libelle)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(touche.estModificateur && ctrlArme ? Teinte.encreSurAccent : Teinte.encre)
                .frame(minWidth: 40, minHeight: 34)
                .background(
                    touche.estModificateur && ctrlArme ? Teinte.accent : Teinte.surface,
                    in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                        .strokeBorder(Teinte.filetAppuye, lineWidth: Trame.trait)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(Haptique.contact, trigger: ctrlArme)
        .accessibilityLabel(touche.effetReel)
    }
}

/// La rangée Ctrl armée. ^U et ^L partent d'un toucher — ils n'effacent qu'une
/// ligne ou un écran. ^C et ^D exigent un MAINTIEN : ils tuent.
struct RangeeControleArme: View {
    let annuler: @MainActor () -> Void
    let envoyer: @MainActor (String) async -> Void

    var body: some View {
        HStack(spacing: Trame.serre) {
            ForEach(ToucheTerminal.raccourcisFrequents, id: \.libelle) { raccourci in
                if tue(raccourci.lettre) {
                    ToucheArmee(libelle: raccourci.libelle, effet: raccourci.effet) {
                        declencher(raccourci.lettre)
                    }
                } else {
                    boutonDirect(raccourci)
                }
            }
            Spacer(minLength: 0)
            Button("Annuler") { annuler() }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Teinte.encreTernie)
        }
        .padding(.horizontal, Trame.ecran)
        .padding(.vertical, Trame.serre)
        .background(Teinte.fondCreux)
        .overlay(alignment: .top) { FiletFin() }
    }

    /// ^C interrompt le processus, ^D peut fermer le shell : les deux tuent.
    private func tue(_ lettre: Character) -> Bool {
        lettre == "c" || lettre == "d"
    }

    private func boutonDirect(
        _ raccourci: (libelle: String, lettre: Character, effet: String)
    ) -> some View {
        Button {
            declencher(raccourci.lettre)
        } label: {
            Text(raccourci.libelle)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Teinte.encre)
                .frame(minWidth: 44, minHeight: 34)
                .background(Teinte.surface, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                        .strokeBorder(Teinte.filetAppuye, lineWidth: Trame.trait)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(raccourci.effet)
    }

    private func declencher(_ lettre: Character) {
        guard let sequence = ToucheTerminal.sequenceControle(lettre) else { return }
        Task { await envoyer(sequence) }
        annuler()
    }
}

/// Une touche qui tue : maintenir 0,5 s pour qu'elle parte. Contrôle autonome
/// — jamais un `Button` décoré d'un geste, qui avalerait le toucher.
private struct ToucheArmee: View {
    let libelle: String
    let effet: String
    let action: @MainActor () -> Void

    @State private var avancee: Double = 0
    @State private var maintenue = false

    var body: some View {
        ZStack {
            forme.fill(Teinte.danger.opacity(0.14))
            GeometryReader { cadre in
                forme
                    .fill(Teinte.danger)
                    .frame(width: cadre.size.width * avancee)
            }
            Text(libelle)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(avancee > 0.4 ? Teinte.fond : Teinte.danger)
        }
        .clipShape(forme)
        .frame(minWidth: 44)
        .frame(height: 34)
        .contentShape(.rect)
        .onLongPressGesture(minimumDuration: 0.5, pressing: { presse in
            maintenue = presse
            withAnimation(presse ? .linear(duration: 0.5) : Elan.vif) {
                avancee = presse ? 1 : 0
            }
        }, perform: {
            withAnimation(Elan.vif) { avancee = 0 }
            action()
        })
        .sensoryFeedback(Haptique.garde, trigger: maintenue) { _, debut in debut }
        .accessibilityLabel("\(libelle) — \(effet). Maintenir pour envoyer.")
    }

    private var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
    }
}
#endif
