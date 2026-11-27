// Pouce haut, pouce bas (avec ses raisons), corriger (`BoutonsRetour.tsx` du web). Sur un tour à plusieurs
// variantes, les pouces désignent la meilleure et la pire.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct BoutonsRetour: View {
    @Environment(Salon.self) private var salon
    let message: MessageChat
    @State private var correctionOuverte = false
    @State private var erreur: String?

    private var comparaison: Bool { salon.positionVariante(de: message) != nil }
    private var haut: Verdict { comparaison ? .meilleure : .positif }
    private var bas: Verdict { comparaison ? .pire : .negatif }
    private var verdict: Verdict? { salon.retours.parMessage[message.id] }
    private var raisons: [RaisonRetour] { salon.retours.raisonsParMessage[message.id] ?? [] }

    var body: some View {
        HStack(spacing: Trame.element) {
            pouce(haut, symbole: "hand.thumbsup", libelle: comparaison ? "Meilleure variante" : "Bonne réponse")
            pouce(bas, symbole: "hand.thumbsdown", libelle: comparaison ? "Pire variante" : "Mauvaise réponse")
            if verdict == bas { menuRaisons }
            Button { correctionOuverte = true } label: {
                Image(systemName: verdict == .correction ? "pencil.line" : "pencil.and.outline").imageScale(.small)
            }
            .buttonStyle(.appui)
            .foregroundStyle(verdict == .correction ? Teinte.accent : Teinte.encreDouce)
            .accessibilityLabel("Corriger cette réponse")
            if let claude = salon.retours.claudeParMessage[message.id] {
                Text("Claude : \(claude.rawValue)").mesureFine().foregroundStyle(Teinte.encreEteinte)
            }
            if erreur != nil {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Teinte.panne).imageScale(.small)
                    .accessibilityLabel(erreur ?? "")
            }
        }
        .disabled(Salon.estLocal(message.id))
        .sheet(isPresented: $correctionOuverte) {
            FeuilleCorrection(initial: Retours.texteFinal(message.contenu)) { texte in
                Task { erreur = await salon.noter(message, .correction, correction: texte) }
            }
        }
    }

    private func pouce(_ cible: Verdict, symbole: String, libelle: String) -> some View {
        Button { Task { erreur = await salon.noter(message, cible) } } label: {
            Image(systemName: verdict == cible ? symbole + ".fill" : symbole).imageScale(.small)
        }
        .buttonStyle(.appui)
        .foregroundStyle(verdict == cible ? Teinte.accent : Teinte.encreDouce)
        .sensoryFeedback(Retour.engage, trigger: verdict)
        .accessibilityLabel(libelle)
    }

    private var menuRaisons: some View {
        Menu {
            ForEach(RaisonRetour.allCases, id: \.self) { raison in
                Button {
                    let suivantes = raisons.contains(raison) ? raisons.filter { $0 != raison } : raisons + [raison]
                    Task { erreur = await salon.noter(message, bas, raisons: suivantes) }
                } label: {
                    if raisons.contains(raison) { Label(raison.libelle, systemImage: "checkmark") } else { Text(raison.libelle) }
                }
            }
        } label: {
            Text(raisons.isEmpty ? "Pourquoi ?" : "\(raisons.count) raison\(raisons.count > 1 ? "s" : "")")
                .legende().foregroundStyle(Teinte.accent)
        }
    }
}

private struct FeuilleCorrection: View {
    let initial: String
    let valider: (String) -> Void
    @Environment(\.dismiss) private var fermer
    @State private var texte = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Trame.element) {
                Text("Écris la version que tu aurais voulue : elle servira d'exemple.")
                    .note().foregroundStyle(Teinte.encreDouce)
                TextEditor(text: $texte).scrollContentBackground(.hidden)
                    .padding(Trame.serre).background(Teinte.surface, in: .rect(cornerRadius: Galbe.carte))
            }
            .padding(Trame.ecran)
            .background(Teinte.fond)
            .navigationTitle("Corriger la réponse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { fermer() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        valider(texte.trimmingCharacters(in: .whitespacesAndNewlines))
                        fermer()
                    }
                    .disabled(texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { texte = initial }
        }
    }
}
#endif
