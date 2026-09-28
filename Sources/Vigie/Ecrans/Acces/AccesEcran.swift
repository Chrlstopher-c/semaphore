// L'accès à distance : chaque appareil du parc, avec ses fichiers, un terminal, et ses sessions Claude (en lancer
// une, s'y attacher dans un vrai terminal, lire son fil). Par le relais : marche en 4G comme à la maison.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct AccesEcran: View {
    @Environment(ModeleRelais.self) private var modele

    var body: some View {
        NavigationStack {
            List(modele.machines) { m in
                NavigationLink(value: m.id) {
                    HStack(spacing: 12) {
                        Circle().fill(m.enLigne ? Color.green : Color(.tertiaryLabel)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.id).font(.headline)
                            Text(m.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .disabled(!m.enLigne)
            }
            .navigationTitle("Accès à distance")
            .navigationDestination(for: String.self) { AppareilEcran(machine: $0) }
            .navigationDestination(for: EmplacementDistant.self) { DossierEcran(lieu: $0) }
            .navigationDestination(for: FichierDistant.self) { FichierEcran(fichier: $0) }
            .navigationDestination(for: CibleTerminal.self) { TerminalEcran(cible: $0) }
            .navigationDestination(for: FilDistant.self) { SessionEcran(id: $0.id) }
        }
    }
}

/// Le fil d'une session ouvert depuis l'accès à distance (distinct du `String` qui désigne une machine ici).
struct FilDistant: Hashable {
    let id: String
}

private struct AppareilEcran: View {
    @Environment(ModeleRelais.self) private var modele
    let machine: String
    @State private var nouvelle = false

    private var sessions: [Session] {
        modele.sessions.filter { $0.machine == machine && $0.ouverte && $0.statut != .fermee }
    }

    var body: some View {
        List {
            Section {
                NavigationLink(value: EmplacementDistant(machine: machine, chemin: nil)) {
                    Label("Fichiers", systemImage: "folder")
                }
                NavigationLink(value: CibleTerminal(machine: machine, titre: "\(machine) · terminal")) {
                    Label("Terminal", systemImage: "apple.terminal")
                }
            }
            Section {
                ForEach(sessions) { ligne($0) }
                Button("Nouvelle session ici", systemImage: "plus") { nouvelle = true }
            } header: {
                Text("Sessions Claude")
            } footer: {
                Text("« Terminal » s’attache à la session : ce que tu tapes lui arrive, et elle continue quand tu fermes.")
            }
        }
        .navigationTitle(machine)
        .sheet(isPresented: $nouvelle) { NouvelleSessionFeuille(machine: machine) }
    }

    private func ligne(_ s: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Charte.couleur(s.statut)).frame(width: 8, height: 8)
                Text(s.titre).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            Text("\(s.projet.nom) · \(s.statut.libelle) · \(Format.depuis(s.majLe))").font(.caption).foregroundStyle(.secondary)
            HStack {
                NavigationLink(value: FilDistant(id: s.id)) { Label("Fil", systemImage: "bubble.left.and.text.bubble.right") }
                if let tmux = s.tmux {
                    NavigationLink(value: CibleTerminal(machine: machine, tmux: tmux, titre: s.titre)) {
                        Label("Terminal", systemImage: "apple.terminal")
                    }
                }
            }
            .buttonStyle(.bordered).controlSize(.small).labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 2)
    }
}
#endif
