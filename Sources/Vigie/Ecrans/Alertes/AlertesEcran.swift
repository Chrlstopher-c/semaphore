// Ce qui mérite l'attention : objectifs atteints, questions, erreurs, étapes. Toucher ouvre la session.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct AlertesEcran: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.palette) private var p
    let ouvrir: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espace.m) {
                EnTeteEcran(surtitre: "fil d’alerte", titre: "Alertes") {
                    Button("Tout lu") { Task { _ = await modele.marquerLues() } }.buttonStyle(StyleBoutonDiscret())
                        .disabled(modele.notifications.isEmpty)
                }
                if modele.notifications.isEmpty {
                    EtatVide(symbole: "bell.slash", titre: "Rien à signaler", texte: "Les objectifs atteints et les questions arrivent ici.")
                }
                ForEach(modele.notifications) { n in
                    Button { if let s = n.sessionId { ouvrir(s) } } label: { LigneAlerte(notification: n) }
                        .buttonStyle(.plain).padding(.horizontal, Espace.marge)
                }
            }
            .padding(.bottom, Espace.xxl)
        }
        .background(p.fond.ignoresSafeArea())
    }
}

private struct LigneAlerte: View {
    @Environment(\.palette) private var p
    let notification: NotificationRelais

    var body: some View {
        HStack(alignment: .top, spacing: Espace.m) {
            Circle().fill(couleur).frame(width: 8, height: 8).padding(.top, 6)
            VStack(alignment: .leading, spacing: Espace.xs) {
                HStack {
                    Text(notification.titre).font(Voix.courant.weight(.bold)).foregroundStyle(p.encre).lineLimit(1)
                    Spacer(minLength: Espace.s)
                    Text(Format.depuis(notification.ts)).font(Voix.etiquette).foregroundStyle(p.discret)
                }
                Text(notification.texte).font(Voix.petit).foregroundStyle(p.encreDouce).lineLimit(3)
            }
        }
        .carte()
        .opacity(notification.lue ? 0.6 : 1)
    }

    private var couleur: Color {
        switch notification.niveau {
        case .info: return p.accentVif
        case .important: return p.succes
        case .alerte: return p.danger
        }
    }
}
#endif
