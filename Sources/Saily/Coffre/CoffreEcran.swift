// L'onglet Coffre : verrouillé par Face ID, puis la liste des secrets de la tour, par nom (leur identifiant).
// Les valeurs ne sont jamais dans la liste : elles se demandent une à une, depuis la fiche.
#if canImport(SwiftUI) && canImport(LocalAuthentication)
import EchoHubNoyau
import SwiftUI

struct CoffreEcran: View {
    @State private var coffre = Coffre.memoire
    @State private var recherche = ""
    @State private var nouveau = false
    @State private var aSupprimer: SecretCoffre?
    @State private var erreur: String?
    @Environment(\.scenePhase) private var phase

    var body: some View {
        NavigationStack {
            ZStack {
                Teinte.fond.ignoresSafeArea()
                contenu
            }
            .navigationTitle("Coffre")
            .toolbar {
                if coffre.etat == .pret {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { nouveau = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Ajouter un secret")
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button { coffre.verrouiller() } label: { Image(systemName: "lock") }
                            .accessibilityLabel("Verrouiller")
                    }
                }
            }
            .navigationDestination(for: String.self) { nom in
                FicheSecret(coffre: coffre, nom: nom)
            }
        }
        .sheet(isPresented: $nouveau) {
            EditeurSecret(coffre: coffre, secret: nil)
        }
        .confirmationDialog(
            "Supprimer « \(aSupprimer?.nom ?? "") » ?", isPresented: suppressionDemandee, titleVisibility: .visible
        ) {
            Button("Supprimer du coffre", role: .destructive) { supprimer() }
        } message: {
            Text("Le secret disparaît de la tour. Rien ne permet de le retrouver.")
        }
        .alert("Échec", isPresented: Binding(get: { erreur != nil }, set: { if !$0 { erreur = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(erreur ?? "")
        }
        // Le coffre se referme dès qu'on le quitte : monde changé ou app en arrière-plan.
        .onDisappear { coffre.verrouiller() }
        .onChange(of: phase) { _, nouvelle in if nouvelle == .background { coffre.verrouiller() } }
    }

    @ViewBuilder private var contenu: some View {
        switch coffre.etat {
        case .verrouille:
            EtatCalme(
                symbole: "lock.shield", titre: "Coffre verrouillé",
                detail: "Les secrets de la tour, protégés par Face ID.",
                actionTitre: "Déverrouiller", action: { Task { await coffre.deverrouiller() } }
            )
            .task { await coffre.deverrouiller() }
        case .chargement:
            ProgressView().tint(Teinte.accent)
        case .echec(let message):
            VStack(spacing: Trame.groupe) {
                EtatCalme(
                    symbole: "externaldrive.badge.xmark", titre: "Coffre injoignable",
                    detail: "\(message)\nLe coffre vit sur la tour : elle doit être allumée.",
                    actionTitre: "Réessayer", action: { Task { await coffre.charger() } }
                )
                Button("Allumer la tour") { Task { await coffre.allumerLaTour() } }
                    .buttonStyle(.appui).foregroundStyle(Teinte.accent)
            }
        case .pret:
            liste
        }
    }

    private var liste: some View {
        List {
            ForEach(filtres) { secret in
                NavigationLink(value: secret.nom) { LigneSecret(secret: secret) }
                    .listRowBackground(Teinte.surface)
                    .swipeActions {
                        Button("Supprimer", role: .destructive) { aSupprimer = secret }
                    }
                    .contextMenu {
                        Button { Coffre.copier(secret.nom) } label: { Label("Copier le nom", systemImage: "doc.on.doc") }
                        Button(role: .destructive) { aSupprimer = secret } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $recherche, prompt: "Nom, type ou note")
        .refreshable { await coffre.charger() }
        .overlay {
            if coffre.secrets.isEmpty {
                EtatCalme(symbole: "tray", titre: "Coffre vide", detail: "Ajoute un secret avec +.")
            }
        }
    }

    private var filtres: [SecretCoffre] {
        let terme = recherche.trimmingCharacters(in: .whitespaces)
        guard !terme.isEmpty else { return coffre.secrets }
        return coffre.secrets.filter {
            $0.nom.localizedCaseInsensitiveContains(terme) || $0.genre.localizedCaseInsensitiveContains(terme)
                || $0.note.localizedCaseInsensitiveContains(terme)
        }
    }

    private var suppressionDemandee: Binding<Bool> {
        Binding(get: { aSupprimer != nil }, set: { if !$0 { aSupprimer = nil } })
    }

    private func supprimer() {
        guard let cible = aSupprimer else { return }
        Task {
            do { try await coffre.supprimer(cible.nom) } catch { erreur = Coffre.libelle(error) }
        }
    }
}

private struct LigneSecret: View {
    let secret: SecretCoffre

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            HStack(spacing: Trame.serre) {
                Text(secret.nom).font(.system(.body, design: .monospaced)).foregroundStyle(Teinte.encre)
                    .lineLimit(1)
                Spacer(minLength: Trame.serre)
                Etiquette(secret.genre)
            }
            if !secret.note.isEmpty {
                Text(secret.note).note().foregroundStyle(Teinte.encreDouce).lineLimit(2)
            }
        }
        .padding(.vertical, Trame.fin)
    }
}
#endif
