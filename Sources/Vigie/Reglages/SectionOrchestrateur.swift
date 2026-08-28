// Section « Orchestrateur » : le profil par défaut d'un nouveau fil (modèle,
// effort, mode rapide, ultracode — `PreferencesOrchestrateur`), et la bascule
// de compte Claude Code sur le poste.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct SectionOrchestrateur: View {
    let modeles: [ModeleApi]
    let comptes: [CompteClaudeApi]
    let bascule: @MainActor (CompteClaudeApi) async -> Void

    @State private var effort: String? = PreferencesOrchestrateur.effort
    @State private var modeRapide = PreferencesOrchestrateur.modeRapide
    @State private var ultracode = PreferencesOrchestrateur.ultracode
    @State private var compteAConfirmer: CompteClaudeApi?
    @State private var basculeEnCours = false

    private var modeleActuel: ModeleApi? {
        PreferencesOrchestrateur.modeleCourant(dans: modeles)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Orchestrateur")
            Panneau {
                if modeles.isEmpty {
                    Text("Le Pi n'a pas encore rendu le catalogue de modèles.")
                        .mention()
                        .foregroundStyle(Teinte.encreTernie)
                } else {
                    VStack(alignment: .leading, spacing: Trame.bloc) {
                        blocModele
                        FiletFin()
                        blocEffort
                        FiletFin()
                        blocBascules
                    }
                }
            }
            blocComptes
        }
        .confirmationDialog(
            "Changer de compte Claude Code",
            isPresented: confirmationPresentee,
            titleVisibility: .visible
        ) {
            boutonsConfirmation
        } message: {
            Text("Les sessions tmux en cours vont être redémarrées pour charger le nouveau compte.")
        }
    }

    // MARK: - Modèle et effort

    private var blocModele: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Text("Modèle par défaut d'un nouveau fil")
                .insigne()
                .foregroundStyle(Teinte.encreDouce)
            FluxPuces(elements: modeles.map(\.id)) { id in
                let modele = modeles.first { $0.id == id }
                Button(modele?.label ?? id) {
                    if let modele { choisirModele(modele) }
                }
                .buttonStyle(.allurePuce(id == modeleActuel?.id ? .attention : .neutre))
                .opacity(modele?.enabled == false ? 0.45 : 1)
            }
            if let note = modeleActuel?.note, !note.isEmpty {
                Text(note).mention().foregroundStyle(Teinte.encreTernie)
            }
        }
    }

    /// `☠` Un modèle sans effort (Haiku) IGNORE le paramètre en silence : le
    /// sélecteur se grise, sinon Chris croit régler quelque chose.
    @ViewBuilder private var blocEffort: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Text("Niveau d'effort")
                .insigne()
                .foregroundStyle(Teinte.encreDouce)
            if let modele = modeleActuel, !modele.effort.isEmpty {
                FluxPuces(elements: modele.effort) { niveau in
                    Button(niveau) { choisirEffort(niveau) }
                        .buttonStyle(.allurePuce(niveau == effort ? .attention : .neutre))
                }
            } else {
                Text("Ce modèle refuse le paramètre d'effort.")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            }
        }
        .sensoryFeedback(Haptique.selection, trigger: effort)
    }

    private var blocBascules: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            bascule(
                "Mode rapide",
                aide: modeleActuel?.fastMode == true ? nil : "réservé à la famille Opus récente",
                valeur: $modeRapide
            )
            .disabled(modeleActuel?.fastMode != true)
            .onChange(of: modeRapide) { _, valeur in PreferencesOrchestrateur.modeRapide = valeur }
            bascule(
                "Ultracode",
                aide: modeleActuel?.ultracode == true
                    ? "xhigh + orchestration de workflows" : "exige un modèle qui l'accepte",
                valeur: $ultracode
            )
            .disabled(modeleActuel?.ultracode != true)
            .onChange(of: ultracode) { _, valeur in PreferencesOrchestrateur.ultracode = valeur }
        }
        .sensoryFeedback(Haptique.selection, trigger: modeRapide)
        .sensoryFeedback(Haptique.selection, trigger: ultracode)
    }

    private func bascule(_ titre: String, aide: String?, valeur: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(titre, isOn: valeur)
                .phrase()
                .foregroundStyle(Teinte.encre)
                .tint(Teinte.accent)
            if let aide {
                Text(aide).mention().foregroundStyle(Teinte.encreTernie)
            }
        }
    }

    private func choisirModele(_ modele: ModeleApi) {
        PreferencesOrchestrateur.modele = modele.id
        effort = PreferencesOrchestrateur.effortCoherent(pour: modele)
        PreferencesOrchestrateur.effort = effort
        if modele.fastMode != true { modeRapide = false }
        if modele.ultracode != true { ultracode = false }
    }

    private func choisirEffort(_ niveau: String) {
        effort = niveau
        PreferencesOrchestrateur.effort = niveau
    }

    // MARK: - Comptes Claude Code

    /// `☠` Rien à voir avec les quotas du harness : ce sont les profils
    /// `CLAUDE_CONFIG_DIR` du poste — la liste exige un poste en ligne.
    private var blocComptes: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            TeteDeSection("Compte Claude Code")
            if comptes.isEmpty {
                Text("Le poste de travail doit être en ligne pour lister les comptes.")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            } else {
                Panneau {
                    VStack(spacing: 0) {
                        ForEach(Array(comptes.enumerated()), id: \.element.id) { rang, compte in
                            ligneCompte(compte, derniere: rang == comptes.count - 1)
                        }
                    }
                }
            }
        }
    }

    private func ligneCompte(_ compte: CompteClaudeApi, derniere: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Trame.serre) {
                Text(compte.label)
                    .donnee()
                    .foregroundStyle(Teinte.encre)
                Spacer(minLength: 0)
                if compte.active {
                    Sceau("actif", ton: .sain)
                } else {
                    Button("Activer") { compteAConfirmer = compte }
                        .buttonStyle(.allurePuce)
                        .disabled(basculeEnCours)
                }
            }
            .padding(.vertical, Trame.serre)
            if !derniere { FiletFin() }
        }
    }

    private var confirmationPresentee: Binding<Bool> {
        Binding(
            get: { compteAConfirmer != nil },
            set: { present in if !present { compteAConfirmer = nil } }
        )
    }

    @ViewBuilder private var boutonsConfirmation: some View {
        Button("Changer de compte", role: .destructive) {
            guard let compte = compteAConfirmer else { return }
            compteAConfirmer = nil
            Task {
                basculeEnCours = true
                await bascule(compte)
                basculeEnCours = false
            }
        }
        Button("Annuler", role: .cancel) { compteAConfirmer = nil }
    }
}
#endif
