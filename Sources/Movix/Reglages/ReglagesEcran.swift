// Le seul réglage du monde : l'adresse de l'instance Movix à charger. Par défaut
// l'instance LAN ; un simple `IP:port` sans schéma est accepté.
#if canImport(SwiftUI)
import SwiftUI
import MovixNoyau

struct ReglagesEcran: View {
    @Environment(ModeleMovix.self) private var modele
    @State private var adresse = ""

    var body: some View {
        ZStack {
            Teinte.fond.ignoresSafeArea()
            ScrollView { contenu }
        }
        .task { adresse = modele.reglages.adresse }
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("Réglages")
                .font(.largeTitle.bold())
                .foregroundStyle(Teinte.encre)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Adresse de l'instance Movix")
                    .font(.headline)
                    .foregroundStyle(Teinte.encre)
                Text("Par défaut l'instance servie sur ton réseau local. Tu peux mettre une IP:port, un domaine ou un tunnel.")
                    .font(.subheadline)
                    .foregroundStyle(Teinte.encreDouce)
            }

            champAdresse
            if modifie { boutonEnregistrer }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    private var champAdresse: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(ReglagesMovix.adresseParDefaut, text: $adresse)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(Teinte.encre)
                .tint(Teinte.accent)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Teinte.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Teinte.trait, lineWidth: 1))
            if !adresseValide {
                Text("Adresse invalide — attendu par ex. \(ReglagesMovix.adresseParDefaut)")
                    .font(.footnote)
                    .foregroundStyle(Teinte.panne)
            }
        }
    }

    private var boutonEnregistrer: some View {
        Button("Enregistrer") { modele.definir(adresse: adresse) }
            .font(.headline)
            .foregroundStyle(Teinte.fond)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Teinte.accent, in: RoundedRectangle(cornerRadius: 12))
            .disabled(!adresseValide)
            .opacity(adresseValide ? 1 : 0.5)
    }

    private var adresseValide: Bool {
        ReglagesMovix(adresse: adresse).adresseValide
    }

    private var modifie: Bool {
        adresse != modele.reglages.adresse
    }
}
#endif
