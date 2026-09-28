// Les sessions du parc, en liste groupée par machine (usages d'Apple Mail) : balayer pour interrompre ou fermer,
// toucher longuement pour tout le reste, rechercher, tirer pour rafraîchir.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ListeSessionsEcran: View {
    @Environment(ModeleRelais.self) private var modele
    @State private var toutes = false
    @State private var recherche = ""
    @State private var nouvelle = false
    @State private var erreur: String?

    var body: some View {
        List {
            if visibles.isEmpty {
                ContentUnavailableView(toutes ? "Aucune session" : "Aucune session ouverte", systemImage: "bubble.left.and.text.bubble.right",
                                       description: Text("Lance-en une sur n’importe quelle machine du parc."))
            }
            ForEach(groupes, id: \.machine) { groupe in
                Section(groupe.machine) {
                    ForEach(groupe.sessions) { s in
                        NavigationLink(value: s.id) { LigneSession(session: s) }
                            .swipeActions(edge: .trailing) { actionsBalayage(s) }
                            .contextMenu { menuContextuel(s) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sessions")
        .searchable(text: $recherche, prompt: "Titre, projet, machine")
        .refreshable { modele.arreter(); modele.demarrer() }
        .toolbar { barreOutils }
        .sheet(isPresented: $nouvelle) { NouvelleSessionFeuille() }
        .alert("Commande refusée", isPresented: Binding(get: { erreur != nil }, set: { if !$0 { erreur = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(erreur ?? "") }
    }

    private var visibles: [Session] {
        let q = recherche.trimmingCharacters(in: .whitespaces).lowercased()
        return modele.sessions.filter { (toutes || estOuverte($0)) && (q.isEmpty || "\($0.titre) \($0.projet.nom) \($0.machine)".lowercased().contains(q)) }
    }

    private var groupes: [(machine: String, sessions: [Session])] {
        Dictionary(grouping: visibles, by: \.machine).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// Une machine hors ligne n'a plus de session vivante : ses sessions ne comptent pas comme ouvertes.
    private func estOuverte(_ s: Session) -> Bool {
        s.vivante && (modele.machines.first { $0.id == s.machine }?.enLigne ?? false)
    }

    @ToolbarContentBuilder private var barreOutils: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Afficher", selection: $toutes) {
                    Label("Ouvertes", systemImage: "bolt").tag(false)
                    Label("Toutes", systemImage: "tray.full").tag(true)
                }
            } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { nouvelle = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nouvelle session")
        }
    }

    @ViewBuilder private func actionsBalayage(_ s: Session) -> some View {
        if s.terminal == true {
            EmptyView()
        } else if estOuverte(s) {
            Button(role: .destructive) { agir(.fermer, s) } label: { Label("Fermer", systemImage: "power") }
            Button { agir(.interrompre, s) } label: { Label("Interrompre", systemImage: "stop.fill") }.tint(.orange)
        } else if s.claudeSessionId != nil {
            Button { agir(.reprendre, s) } label: { Label("Reprendre", systemImage: "play.fill") }.tint(Charte.accent)
        }
    }

    @ViewBuilder private func menuContextuel(_ s: Session) -> some View {
        if s.terminal == true {
            Text("Ouverte dans un terminal : lecture seule")
        } else if estOuverte(s) {
            Button { agir(.interrompre, s) } label: { Label("Interrompre", systemImage: "stop.fill") }
            Button { agir(.compacter, s) } label: { Label("Compacter", systemImage: "arrow.down.right.and.arrow.up.left") }
            Button(role: .destructive) { agir(.fermer, s) } label: { Label("Fermer", systemImage: "power") }
        } else {
            Button { agir(.reprendre, s) } label: { Label("Reprendre", systemImage: "play.fill") }.disabled(s.claudeSessionId == nil)
        }
    }

    private func agir(_ action: ActionSession, _ s: Session) {
        Task { erreur = await modele.agir(action, sur: s.id) }
    }
}

struct LigneSession: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            PointEtat(statut: session.statut)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.titre).font(.body.weight(.semibold)).lineLimit(1)
                Text("\(session.projet.nom) · \(session.statut.libelle.lowercased())")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if session.statut == .question {
                Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange)
            }
            Text(session.contexte.tokens > 0 ? Format.tokens(session.contexte.tokens) : Format.depuis(session.majLe))
                .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
#endif
