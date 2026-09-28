// Une session : son fil en direct (comme une conversation Messages), ses actions dans le menu de la barre, et de quoi
// lui écrire en bas, posé sur la matière du système.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct SessionEcran: View {
    @Environment(ModeleRelais.self) private var modele
    let id: String
    @State private var erreur: String?

    var body: some View {
        Group {
            if let s = modele.session(id) {
                FilVue(evenements: modele.fils[id] ?? [], dossier: s.cwd, entete: { EtatSession(session: s) })
                    .safeAreaInset(edge: .bottom) { ComposeurSession(session: s, erreur: $erreur) }
                    .navigationTitle(s.titre)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { MenuSession(session: s, erreur: $erreur) } }
            } else {
                ContentUnavailableView("Session introuvable", systemImage: "questionmark.circle",
                                       description: Text("Elle a peut-être été retirée du relais."))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: id) { await modele.suivreFil(id) }
        .onAppear { Aiguillage.partage.sessionVisible = id }
        .onDisappear { Aiguillage.partage.sessionVisible = nil }
        .alert("Commande refusée", isPresented: Binding(get: { erreur != nil }, set: { if !$0 { erreur = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(erreur ?? "") }
    }
}

/// L'état de la session en tête du fil : statut, machine, modèle, contexte relu à chaque tour.
struct EtatSession: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                PointEtat(statut: session.statut)
                Text(session.statut.libelle).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(session.machine) · \(session.projet.nom)").font(.footnote).foregroundStyle(.secondary)
            }
            // Rouge au seuil de compaction dure (35 % d'une fenêtre de 1 M) : au-delà, chaque tour coûte cher.
            Gauge(value: min(session.contexte.ratio, 1)) {} currentValueLabel: {}
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(session.contexte.ratio >= 0.35 ? .red : Charte.accent)
            HStack {
                Text("\(Format.tokens(session.contexte.tokens)) / \(Format.tokens(session.contexte.max)) de contexte")
                Spacer()
                Text("\(session.etapes) ét. · \(session.compactions) comp. · \(session.modele)")
            }
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}

/// Les actions de la session, dans le menu « … » de la barre de navigation.
struct MenuSession: View {
    @Environment(ModeleRelais.self) private var modele
    let session: Session
    @Binding var erreur: String?

    var body: some View {
        Menu {
            if session.ouverte {
                Button { agir(.interrompre) } label: { Label("Interrompre", systemImage: "stop.fill") }
                Button { agir(.compacter) } label: { Label("Compacter", systemImage: "arrow.down.right.and.arrow.up.left") }
            }
            if session.pilotee {
                Toggle(isOn: Binding(get: { session.autonomie }, set: { v in
                    Task { erreur = await modele.basculerAutonomie(v, de: session.id) }
                })) { Label("Autonomie", systemImage: "infinity") }
            }
            Divider()
            if session.ouverte {
                Button(role: .destructive) { agir(.fermer) } label: { Label("Fermer la session", systemImage: "power") }
            } else {
                Button { agir(.reprendre) } label: { Label("Reprendre", systemImage: "play.fill") }.disabled(session.claudeSessionId == nil)
            }
        } label: { Image(systemName: "ellipsis.circle") }
    }

    private func agir(_ action: ActionSession) {
        Task { erreur = await modele.agir(action, sur: session.id) }
    }
}

struct ComposeurSession: View {
    @Environment(ModeleRelais.self) private var modele
    let session: Session
    @Binding var erreur: String?
    @State private var texte = ""
    @State private var envoi = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(aide, text: $texte, axis: .vertical)
                .lineLimit(1...6)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().strokeBorder(Color(.separator)))
            Button { Task { await envoyer() } } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)).symbolRenderingMode(.hierarchical)
            }
            .disabled(texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || envoi)
            .accessibilityLabel("Envoyer")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
        .sensoryFeedback(.impact(weight: .medium), trigger: envoi)
    }

    private var aide: String {
        if !session.ouverte { return "Écrire la reprend" }
        return session.statut.enActivite ? "Lu à la fin de son tour" : "Message"
    }

    private func envoyer() async {
        let t = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        envoi = true
        defer { envoi = false }
        if let e = await modele.envoyer(t, a: session.id) { erreur = e } else { texte = "" }
    }
}
#endif
