// La fiche d'un secret : son nom (l'identifiant du coffre), sa valeur masquée tant qu'on ne la demande pas,
// et les gestes — copier, modifier, supprimer.
#if canImport(SwiftUI) && canImport(LocalAuthentication)
import EchoHubNoyau
import SwiftUI

struct FicheSecret: View {
    let coffre: Coffre
    let nom: String
    @State private var valeur: String?
    @State private var lecture = false
    @State private var edition = false
    @State private var suppression = false
    @State private var erreur: String?
    @Environment(\.dismiss) private var fermer

    private var secret: SecretCoffre? { coffre.secrets.first { $0.nom == nom } }

    var body: some View {
        ZStack {
            Teinte.fond.ignoresSafeArea()
            if let secret {
                ScrollView { contenu(secret) }
            } else {
                EtatCalme(symbole: "questionmark.square.dashed", titre: "Secret introuvable", detail: "Il a pu être renommé ou supprimé.")
            }
        }
        .navigationTitle(nom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if secret != nil {
                ToolbarItem(placement: .topBarTrailing) { Button("Modifier") { edition = true } }
            }
        }
        .sheet(isPresented: $edition) {
            if let secret { EditeurSecret(coffre: coffre, secret: secret) }
        }
        .confirmationDialog("Supprimer « \(nom) » ?", isPresented: $suppression, titleVisibility: .visible) {
            Button("Supprimer du coffre", role: .destructive) { supprimer() }
        } message: {
            Text("Le secret disparaît de la tour. Rien ne permet de le retrouver.")
        }
        .alert("Échec", isPresented: Binding(get: { erreur != nil }, set: { if !$0 { erreur = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(erreur ?? "")
        }
        // Une valeur révélée ne survit pas à la fiche.
        .onDisappear { valeur = nil }
        // Renommé ou supprimé (ici ou ailleurs) : cette fiche ne désigne plus rien, on revient à la liste.
        .onChange(of: secret == nil) { _, disparu in if disparu { fermer() } }
    }

    private func contenu(_ secret: SecretCoffre) -> some View {
        VStack(alignment: .leading, spacing: Trame.groupe) {
            Panneau {
                VStack(alignment: .leading, spacing: Trame.element) {
                    Text("Identifiant").rubrique()
                    HStack {
                        Text(secret.nom).font(.system(.body, design: .monospaced)).foregroundStyle(Teinte.encre)
                            .textSelection(.enabled)
                        Spacer()
                        BoutonCopie { Coffre.copier(secret.nom) }
                    }
                }
            }
            Panneau { blocValeur }
            Panneau {
                VStack(alignment: .leading, spacing: Trame.element) {
                    ligne("Type", secret.genre)
                    if !secret.note.isEmpty { ligne("Note", secret.note) }
                    ligne("Créé", secret.creeLe.formatted(date: .abbreviated, time: .shortened))
                    ligne("Modifié", secret.modifieLe.formatted(date: .abbreviated, time: .shortened))
                }
            }
            Button("Supprimer du coffre", role: .destructive) { suppression = true }
                .buttonStyle(.appui).foregroundStyle(Teinte.panne)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Trame.ecran)
        .padding(.vertical, Trame.groupe)
    }

    private var blocValeur: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            Text("Valeur").rubrique()
            HStack(alignment: .top) {
                Text(valeur ?? "••••••••••••")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(valeur == nil ? Teinte.encreEteinte : Teinte.encre)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if lecture { ProgressView().tint(Teinte.accent) }
            }
            HStack(spacing: Trame.groupe) {
                Button(valeur == nil ? "Afficher" : "Masquer") {
                    if valeur == nil { Task { await lire() } } else { valeur = nil }
                }
                Button("Copier") {
                    Task {
                        if let texte = await lireSansAfficher() { Coffre.copier(texte) }
                    }
                }
                Spacer()
            }
            .buttonStyle(.appui).foregroundStyle(Teinte.accent).disabled(lecture)
            Text("Une copie s'efface du presse-papiers au bout d'une minute.")
                .legende().foregroundStyle(Teinte.encreEteinte)
        }
    }

    private func ligne(_ titre: String, _ texte: String) -> some View {
        HStack(alignment: .top) {
            Text(titre).legende().foregroundStyle(Teinte.encreDouce).frame(width: 72, alignment: .leading)
            Text(texte).corps().foregroundStyle(Teinte.encre).textSelection(.enabled)
        }
    }

    private func lire() async {
        valeur = await lireSansAfficher()
    }

    private func lireSansAfficher() async -> String? {
        if let valeur { return valeur }
        lecture = true
        defer { lecture = false }
        do { return try await coffre.valeur(nom) } catch {
            erreur = Coffre.libelle(error)
            return nil
        }
    }

    private func supprimer() {
        Task {
            do {
                try await coffre.supprimer(nom)
                fermer()
            } catch { erreur = Coffre.libelle(error) }
        }
    }
}

private struct BoutonCopie: View {
    let action: () -> Void
    @State private var copie = false

    var body: some View {
        Button {
            action()
            copie = true
        } label: {
            Image(systemName: copie ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.appui).foregroundStyle(Teinte.accent)
        .sensoryFeedback(.success, trigger: copie)
        .accessibilityLabel("Copier l'identifiant")
    }
}
#endif
