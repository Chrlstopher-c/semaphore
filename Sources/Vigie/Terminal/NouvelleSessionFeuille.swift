// Feuille de lancement d'une session tmux. Un seul champ : le nom, avec
// « claude » en repli — le nom que pi-web donne par défaut.
#if canImport(SwiftUI)
import SwiftUI

struct NouvelleSessionFeuille: View {
    let creer: @MainActor (String) async -> Void

    @State private var nom = ""
    @State private var enCours = false
    @FocusState private var enFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.bloc) {
            Text("Nouvelle session")
                .titreFeuille()
                .foregroundStyle(Teinte.encre)
            ChampQuart(
                "Nom",
                texte: $nom,
                placebo: "claude",
                aide: "Laissé vide, la session s'appellera « claude »."
            )
            .focused($enFocus)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            Button {
                Task { await lancer() }
            } label: {
                HStack(spacing: Trame.serre) {
                    if enCours { SouffleActivite(teinte: Teinte.encreSurAccent) }
                    Text(enCours ? "Lancement…" : "Lancer")
                }
            }
            .buttonStyle(.allureAccent)
            .disabled(enCours)
            Spacer(minLength: 0)
        }
        .padding(Trame.ecran)
        .task { enFocus = true }
        .rendLeClavierSansDefilement()
    }

    @MainActor private func lancer() async {
        guard !enCours else { return }
        enCours = true
        await creer(nom)
        enCours = false
    }
}
#endif
