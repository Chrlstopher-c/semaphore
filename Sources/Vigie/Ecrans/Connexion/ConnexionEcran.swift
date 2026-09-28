// Se connecter au relais : un formulaire système. Le mot de passe s'échange contre un jeton gardé dans le trousseau.
#if canImport(SwiftUI)
import SwiftUI

struct ConnexionEcran: View {
    @Environment(Cablage.self) private var cablage
    @State private var adresse = ""
    @State private var motDePasse = ""
    @State private var erreur: String?
    @State private var envoi = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Adresse du relais", text: $adresse).keyboardType(.URL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Mot de passe", text: $motDePasse).textContentType(.password)
                } footer: {
                    Text("Les sessions Claude Code de tout le parc, depuis le téléphone.")
                }
                if let erreur { Section { Text(erreur).foregroundStyle(.red) } }
                Section {
                    Button { Task { await connecter() } } label: {
                        HStack { Spacer(); Text(envoi ? "Connexion…" : "Se connecter").bold(); Spacer() }
                    }
                    .disabled(envoi || motDePasse.isEmpty)
                }
            }
            .navigationTitle("Vigie")
            .onAppear { if adresse.isEmpty { adresse = cablage.adresse.absoluteString } }
            .sensoryFeedback(.error, trigger: erreur)
        }
    }

    private func connecter() async {
        guard let url = URL(string: adresse.trimmingCharacters(in: .whitespaces)) else {
            erreur = "Adresse invalide."
            return
        }
        envoi = true
        defer { envoi = false }
        do {
            try await cablage.connecter(adresse: url, motDePasse: motDePasse)
        } catch {
            erreur = "\(error)"
        }
    }
}
#endif
