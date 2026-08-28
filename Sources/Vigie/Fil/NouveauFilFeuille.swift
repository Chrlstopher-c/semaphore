// Création d'un fil, et renommage — les deux feuilles courtes du domaine.
//
// `☠` La machine est proposée depuis la liste RÉELLE du parc : le serveur
// refuse toute machine inconnue en 400 avec la liste des disponibles, et un
// fil rattaché à rien devient irroutable dès qu'une seconde machine s'allume.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct NouveauFilFeuille: View {
    let machines: [MachineApi]
    /// Rend vrai si la création a abouti — la feuille se referme alors.
    let creer: @MainActor (String, String?) async -> Bool

    @Environment(\.dismiss) private var congedier
    @State private var titre = ""
    @State private var machine: String?
    @State private var enCours = false
    @FocusState private var enFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.bloc) {
            Text("Nouveau fil")
                .titreFeuille()
                .foregroundStyle(Teinte.encre)
            ChampQuart(
                "Titre",
                texte: $titre,
                placebo: "Sans titre",
                aide: "Laissé vide, l'orchestrateur le nommera lui-même."
            )
            .focused($enFocus)
            choixMachine
            bouton
            Spacer(minLength: 0)
        }
        .padding(Trame.ecran)
        .task { enFocus = true }
        .rendLeClavierSansDefilement()
    }

    @ViewBuilder private var choixMachine: some View {
        if !machines.isEmpty {
            VStack(alignment: .leading, spacing: Trame.serre) {
                Text("Machine")
                    .insigne()
                    .foregroundStyle(Teinte.encreDouce)
                HStack(spacing: Trame.serre) {
                    ForEach(machines) { candidate in
                        puce(candidate)
                    }
                }
                Text("Sans choix, le Pi rattache le fil à la première machine venue.")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            }
        }
    }

    private func puce(_ candidate: MachineApi) -> some View {
        let choisie = machine == candidate.id
        return Button {
            machine = choisie ? nil : candidate.id
        } label: {
            HStack(spacing: Trame.fin) {
                PointVeille(ton: candidate.enLigne ? .sain : .veille)
                Text(candidate.id)
            }
        }
        .buttonStyle(.allurePuce(choisie ? .attention : .neutre))
        .sensoryFeedback(Haptique.selection, trigger: machine)
    }

    private var bouton: some View {
        Button {
            Task { await lancer() }
        } label: {
            HStack(spacing: Trame.serre) {
                if enCours { SouffleActivite(teinte: Teinte.encreSurAccent) }
                Text(enCours ? "Ouverture…" : "Ouvrir le fil")
            }
        }
        .buttonStyle(.allureAccent)
        .disabled(enCours)
    }

    @MainActor private func lancer() async {
        guard !enCours else { return }
        enCours = true
        let titrePropre = titre.trimmingCharacters(in: .whitespacesAndNewlines)
        if await creer(titrePropre, machine) { congedier() }
        enCours = false
    }
}

/// Renommage d'un fil existant — même pièce courte, un seul champ.
struct RenommerFilFeuille: View {
    let fil: FilApi
    let renommer: @MainActor (String) async -> Void

    @State private var titre = ""
    @State private var enCours = false
    @FocusState private var enFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.bloc) {
            Text("Renommer le fil")
                .titreFeuille()
                .foregroundStyle(Teinte.encre)
            ChampQuart("Titre", texte: $titre, placebo: fil.titre)
                .focused($enFocus)
            Button(enCours ? "Renommage…" : "Renommer") {
                Task { await confirmer() }
            }
            .buttonStyle(.allureAccent)
            .disabled(enCours || titre.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer(minLength: 0)
        }
        .padding(Trame.ecran)
        .task {
            titre = fil.titre
            enFocus = true
        }
        .rendLeClavierSansDefilement()
    }

    @MainActor private func confirmer() async {
        guard !enCours else { return }
        enCours = true
        await renommer(titre.trimmingCharacters(in: .whitespacesAndNewlines))
        enCours = false
    }
}
#endif
