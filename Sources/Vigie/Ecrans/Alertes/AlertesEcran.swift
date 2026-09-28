// Ce qui mérite l'attention : objectifs atteints, questions, erreurs, étapes. Toucher ouvre la session.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct AlertesEcran: View {
    @Environment(ModeleRelais.self) private var modele
    let ouvrir: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                if modele.notifications.isEmpty {
                    ContentUnavailableView("Rien à signaler", systemImage: "bell.slash",
                                           description: Text("Les objectifs atteints et les questions arrivent ici."))
                }
                ForEach(modele.notifications) { n in
                    Button { if let s = n.sessionId { ouvrir(s) } } label: { LigneAlerte(notification: n) }
                        .foregroundStyle(.primary)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Alertes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tout lu") { Task { _ = await modele.marquerLues() } }.disabled(modele.notifications.isEmpty)
                }
            }
        }
    }
}

private struct LigneAlerte: View {
    let notification: NotificationRelais

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbole).foregroundStyle(couleur)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(notification.titre).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer()
                    Text(Format.depuis(notification.ts)).font(.caption).foregroundStyle(.secondary)
                }
                Text(notification.texte).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            }
        }
        .opacity(notification.lue ? 0.55 : 1)
        .padding(.vertical, 2)
    }

    private var symbole: String {
        switch notification.niveau {
        case .info: return "flag.fill"
        case .important: return notification.titre.hasSuffix("question") ? "questionmark.circle.fill" : "checkmark.circle.fill"
        case .alerte: return "exclamationmark.triangle.fill"
        }
    }

    private var couleur: Color {
        switch notification.niveau {
        case .info: return Charte.accent
        case .important: return notification.titre.hasSuffix("question") ? .orange : .green
        case .alerte: return .red
        }
    }
}
#endif
