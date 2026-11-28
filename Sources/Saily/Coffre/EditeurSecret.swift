// Ajouter ou modifier un secret. En modification, une valeur laissée vide garde l'ancienne :
// on peut renommer ou annoter sans jamais faire revenir le secret à l'écran.
#if canImport(SwiftUI) && canImport(LocalAuthentication)
import EchoHubNoyau
import SwiftUI

struct EditeurSecret: View {
    let coffre: Coffre
    /// `nil` = nouveau secret.
    let secret: SecretCoffre?
    @State private var nom = ""
    @State private var valeur = ""
    @State private var genre = "secret"
    @State private var note = ""
    @State private var envoi = false
    @State private var erreur: String?
    @Environment(\.dismiss) private var fermer

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ex. saily-token", text: $nom)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: { Text("Identifiant") } footer: {
                    if secret != nil, nomPropre != secret?.nom { Text("Le secret sera renommé.") }
                }
                Section {
                    SecureField(secret == nil ? "Valeur" : "Laisser vide pour garder l'actuelle", text: $valeur)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: { Text("Valeur") }
                Section("Type") {
                    Picker("Type", selection: $genre) {
                        ForEach(genres, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Section("Note") {
                    TextField("À quoi il sert", text: $note, axis: .vertical)
                }
                if let erreur {
                    Section { Text(erreur).foregroundStyle(Teinte.panne) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Teinte.fond)
            .navigationTitle(secret == nil ? "Nouveau secret" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { Task { await enregistrer() } }.disabled(!valide || envoi)
                }
            }
        }
        .onAppear {
            guard let secret else { return }
            nom = secret.nom
            genre = secret.genre
            note = secret.note
        }
        .interactiveDismissDisabled(envoi)
    }

    private var nomPropre: String { nom.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var valide: Bool { !nomPropre.isEmpty && (secret != nil || !valeur.isEmpty) }

    /// Les genres connus, plus celui du secret s'il est ailleurs.
    private var genres: [String] {
        GenresSecret.tous.contains(genre) ? GenresSecret.tous : GenresSecret.tous + [genre]
    }

    private func enregistrer() async {
        envoi = true
        defer { envoi = false }
        do {
            if let secret {
                try await coffre.modifier(secret.nom, EditionSecret(
                    nom: nomPropre == secret.nom ? nil : nomPropre,
                    valeur: valeur.isEmpty ? nil : valeur,
                    genre: genre, note: note
                ))
            } else {
                try await coffre.creer(EditionSecret(nom: nomPropre, valeur: valeur, genre: genre, note: note))
            }
            fermer()
        } catch {
            erreur = Coffre.libelle(error)
        }
    }
}
#endif
