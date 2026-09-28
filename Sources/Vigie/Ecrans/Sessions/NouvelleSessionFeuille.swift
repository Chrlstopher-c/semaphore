// Lancer une session depuis le téléphone : où elle tourne, sur quel projet (de n'importe quelle machine joignable),
// avec quel objectif. Le VPS, isolé, ne voit que ses propres projets.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct NouvelleSessionFeuille: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var fermer
    @State private var machine = ""
    @State private var projet: Projet?
    @State private var objectif = ""
    @State private var message = ""
    @State private var autonomie = true
    @State private var modeleClaude = ""
    @State private var erreur: String?
    @State private var envoi = false

    private let isolee = "vps"

    var body: some View {
        NavigationStack {
            Form {
                Section("Où") { choixMachine; choixProjet; choixModele }
                Section("Quoi") {
                    TextField("Objectif (la session travaille jusqu’à l’atteindre)", text: $objectif, axis: .vertical).lineLimit(2...4)
                    TextField("Premier message", text: $message, axis: .vertical).lineLimit(3...8)
                    Toggle("Autonomie", isOn: $autonomie).tint(p.accent)
                }
                if let erreur { Section { Text(erreur).foregroundStyle(p.danger) } }
            }
            .scrollContentBackground(.hidden)
            .background(p.fond)
            .navigationTitle("Nouvelle session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(envoi ? "…" : "Lancer") { Task { await lancer() } }.disabled(!pret || envoi).bold()
                }
            }
            .onAppear(perform: choisirParDefaut)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Rayon.feuille)
        .tint(p.accent)
    }

    private var enLigne: [Machine] { modele.machines.filter(\.enLigne) }
    private var pret: Bool { projet != nil && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var choixMachine: some View {
        Picker("Machine", selection: $machine) { ForEach(enLigne) { Text($0.id).tag($0.id) } }
            .onChange(of: machine) { _, m in projet = modele.machines.first { $0.id == m }?.projets.first }
    }

    private var choixProjet: some View {
        Picker("Projet", selection: $projet) {
            ForEach(modele.machines.filter { machine != isolee || $0.id == isolee }) { m in
                Section(m.id) { ForEach(m.projets, id: \.self) { Text($0.nom).tag(Optional($0)) } }
            }
        }
    }

    private var choixModele: some View {
        Picker("Modèle", selection: $modeleClaude) {
            Text("Par défaut").tag("")
            Text("Opus").tag("opus")
            Text("Sonnet").tag("sonnet")
            Text("Haiku").tag("haiku")
        }
    }

    private func choisirParDefaut() {
        guard machine.isEmpty, let premiere = enLigne.first(where: { $0.id == "tour" }) ?? enLigne.first else { return }
        machine = premiere.id
        projet = premiere.projets.first
    }

    private func lancer() async {
        guard let projet else { return }
        envoi = true
        defer { envoi = false }
        let objectifNet = objectif.trimmingCharacters(in: .whitespacesAndNewlines)
        let demande = DemandeOuverture(machine: machine, projet: projet, message: message, titre: nil,
                                       objectif: objectifNet.isEmpty ? nil : objectifNet, autonomie: autonomie,
                                       modele: modeleClaude.isEmpty ? nil : modeleClaude)
        switch await modele.ouvrir(demande) {
        case .success(let s):
            fermer()
            Aiguillage.partage.sessionDemandee = s.id
        case .failure(let e): erreur = e.description
        }
    }
}
#endif
