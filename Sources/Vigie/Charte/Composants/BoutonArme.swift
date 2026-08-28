// Le geste armé : maintenir 1,2 s pour l'irréversible — terminer une équipe,
// fermer la session. L'anneau se remplit sous le doigt, l'haptique marque
// l'armement puis l'engagement.
//
// `☠` Contrôle AUTONOME, jamais un `Button` décoré d'un geste : un
// `onLongPressGesture` posé sur un `Button` avale le toucher en silence. Ici
// le geste est le contrôle lui-même, il n'a personne à qui voler le toucher.
#if canImport(SwiftUI)
import SwiftUI

public struct BoutonArme: View {
    private let libelle: String
    private let libelleArme: String
    private let duree: Double
    private let action: @MainActor () -> Void

    @State private var avancee: Double = 0
    @State private var maintenu = false
    @State private var engage = false

    public init(
        _ libelle: String,
        libelleArme: String = "Maintiens…",
        duree: Double = 1.2,
        action: @escaping @MainActor () -> Void
    ) {
        self.libelle = libelle
        self.libelleArme = libelleArme
        self.duree = duree
        self.action = action
    }

    public var body: some View {
        ZStack {
            forme.fill(Teinte.danger.opacity(0.14))
            GeometryReader { cadre in
                forme
                    .fill(Teinte.danger)
                    .frame(width: cadre.size.width * avancee)
            }
            Text(maintenu ? libelleArme : libelle)
                .libelle()
                .foregroundStyle(avancee > 0.45 ? Teinte.fond : Teinte.danger)
        }
        .clipShape(forme)
        .frame(height: Trame.cibleDecision)
        .contentShape(.rect)
        .onLongPressGesture(minimumDuration: duree, pressing: presser, perform: aboutir)
        .sensoryFeedback(Haptique.garde, trigger: maintenu) { _, debut in debut }
        .sensoryFeedback(Haptique.engagement, trigger: engage)
        .accessibilityLabel(libelle)
        .accessibilityHint("Maintenir \(Int(duree.rounded())) seconde pour confirmer")
    }

    private var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: Galbe.bouton, style: .continuous)
    }

    private func presser(_ enCours: Bool) {
        maintenu = enCours
        withAnimation(enCours ? .linear(duration: duree) : Elan.vif) {
            avancee = enCours ? 1 : 0
        }
    }

    private func aboutir() {
        engage.toggle()
        maintenu = false
        withAnimation(Elan.vif) { avancee = 0 }
        action()
    }
}
#endif
