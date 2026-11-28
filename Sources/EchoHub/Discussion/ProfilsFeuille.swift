// Les profils (`ModaleProfils.tsx`, `SelecteurProfil.tsx` du web) : celui que suit cette session, celui des
// sessions neuves, et leur gestion. Choisir un profil remplace style, outils et réglages de la session.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct ProfilsFeuille: View {
    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @AppStorage(Salon.cleProfilNeuf) private var profilNeuf = ""
    @State private var profils: EtatChargement<[Profil]> = .chargement
    @State private var lie: String?
    @State private var erreur: String?
    @State private var edition: EditionEnCours?
    @State private var aSupprimer: Profil?

    var body: some View {
        NavigationStack {
            List {
                if let erreur { Text(erreur).foregroundStyle(Teinte.panne) }
                switch profils {
                case .chargement, .vide: ProgressView()
                case .echec(let raison): Text(raison).foregroundStyle(Teinte.panne)
                case .pret(let liste): sections(liste)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Teinte.fond)
            .navigationTitle("Profils")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Fermer") { fermer() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { edition = EditionEnCours(id: nil, edition: EditionProfil(nom: "Nouveau profil")) } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nouveau profil")
                }
            }
            .task { await charger() }
            .confirmationDialog(
                "Supprimer le profil « \(aSupprimer?.nom ?? "") » ?",
                isPresented: Binding(get: { aSupprimer != nil }, set: { if !$0 { aSupprimer = nil } }),
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    if let profil = aSupprimer { Task { await supprimer(profil) } }
                }
            } message: {
                Text("Les sessions qui le suivent gardent leurs réglages actuels.")
            }
            .sheet(item: $edition) { enCours in
                EditeurProfil(depart: enCours) { await charger() }
            }
        }
    }

    @ViewBuilder private func sections(_ liste: [Profil]) -> some View {
        Section {
            ligne("Aucun — réglages propres", choisi: lie == nil) { await choisir(nil) }
            ForEach(liste) { profil in
                ligne(profil.nom, detail: resume(profil.edition), choisi: lie == profil.id) { await choisir(profil.id) }
                    .swipeActions {
                        Button(role: .destructive) { aSupprimer = profil } label: { Label("Supprimer", systemImage: "trash") }
                        Button { edition = EditionEnCours(id: profil.id, edition: profil.edition) } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        .tint(Teinte.accent)
                    }
            }
        } header: {
            Text("Cette session")
        } footer: {
            Text("Modifier ensuite un réglage à la main détache la session de son profil. Glisser une ligne pour modifier ou supprimer.")
        }
        Section {
            Picker("Profil des sessions neuves", selection: $profilNeuf) {
                Text("Aucun").tag("")
                ForEach(liste) { Text($0.nom).tag($0.id) }
            }
        }
    }

    private func ligne(_ titre: String, detail: String? = nil, choisi: Bool, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            HStack {
                VStack(alignment: .leading, spacing: Trame.fin) {
                    Text(titre).foregroundStyle(Teinte.encre)
                    if let detail { Text(detail).legende().foregroundStyle(Teinte.encreDouce) }
                }
                Spacer(minLength: 0)
                if choisi { Image(systemName: "checkmark").foregroundStyle(Teinte.accent) }
            }
        }
        .disabled(salon.conversation == nil)
    }

    private func resume(_ edition: EditionProfil) -> String {
        var morceaux = [edition.outils.map { "\($0.count) outils" } ?? "Tous les outils"]
        morceaux.append(String(format: "T %.2f", edition.parametres.temperature))
        if edition.modeProjet { morceaux.append("projet") }
        if edition.hybride { morceaux.append("Haiku code") }
        return morceaux.joined(separator: " · ")
    }

    private func charger() async {
        do {
            let liste = try await salon.profils.lister()
            if let id = salon.conversation?.id { lie = try await salon.profils.profil(deLaConversation: id) }
            profils = .pret(liste)
        } catch {
            profils = .echec(Salon.libelle(error))
        }
    }

    private func choisir(_ profil: String?) async {
        guard let id = salon.conversation?.id else { return }
        do {
            lie = try await salon.profils.choisir(id, profil: profil)
            salon.poser(reglages: try await salon.conversations.reglages(id))
            salon.poser(outils: try await salon.outils.selection(id))
            erreur = nil
        } catch {
            erreur = Salon.libelle(error)
        }
    }

    private func supprimer(_ profil: Profil) async {
        do {
            try await salon.profils.supprimer(profil.id)
            if profilNeuf == profil.id { profilNeuf = "" }
            await charger()
        } catch {
            erreur = Salon.libelle(error)
        }
    }
}

struct EditionEnCours: Identifiable {
    let id: String?
    var edition: EditionProfil
}

/// Le formulaire d'un profil (`EditeurProfil.tsx`) : nom, style, mode projet, Haiku, outils, réglages du modèle.
private struct EditeurProfil: View {
    let depart: EditionEnCours
    let apres: () async -> Void
    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @State private var brouillon = EditionProfil()
    @State private var catalogue: [OutilDisponible] = []
    @State private var erreur: String?
    @State private var enregistre = false

    var body: some View {
        NavigationStack {
            Form {
                if let erreur { Text(erreur).foregroundStyle(Teinte.panne) }
                Section("Nom") { TextField("Nom", text: $brouillon.nom) }
                Section("Style") {
                    TextField("Le prompt système de ce profil", text: $brouillon.style, axis: .vertical).lineLimit(3...10)
                }
                Section {
                    Toggle("Mode projet", isOn: $brouillon.modeProjet)
                    Toggle("Haiku écrit le code", isOn: $brouillon.hybride).disabled(!brouillon.modeProjet)
                }
                Section("Outils") {
                    Toggle("Tous les outils", isOn: Binding(
                        get: { brouillon.outils == nil },
                        set: { brouillon.outils = $0 ? nil : catalogue.map(\.nom) }
                    ))
                    if let actifs = brouillon.outils {
                        ForEach(catalogue) { outil in
                            Toggle(outil.nom, isOn: Binding(
                                get: { actifs.contains(outil.nom) },
                                set: { brouillon.outils = $0 ? actifs + [outil.nom] : actifs.filter { $0 != outil.nom } }
                            ))
                        }
                    }
                }
                Section("Réglages du modèle") {
                    CurseurReglage("Température", valeur: $brouillon.parametres.temperature, plage: 0...2, pas: 0.05, detail: "Plus haut, plus imprévisible.")
                    CurseurReglage("Top-p", valeur: $brouillon.parametres.topP, plage: 0.01...1, pas: 0.01, detail: "La masse de probabilité retenue.")
                    CurseurReglage("Top-k", valeur: Binding(
                        get: { Double(brouillon.parametres.topK) }, set: { brouillon.parametres.topK = Int($0.rounded()) }
                    ), plage: 0...200, pas: 1, detail: "0 = aucune coupe.")
                    CurseurReglage("Min-p", valeur: $brouillon.parametres.minP, plage: 0...1, pas: 0.01, detail: "0 = inactif.")
                    CurseurReglage("Pénalité de répétition", valeur: $brouillon.parametres.penaliteRepetition, plage: 0...2, pas: 0.01, detail: "1 = neutre.")
                    CurseurReglage("Pénalité de présence", valeur: $brouillon.parametres.penalitePresence, plage: 0...2, pas: 0.05, detail: "Contre les boucles.")
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Teinte.fond)
            .navigationTitle(depart.id == nil ? "Nouveau profil" : "Modifier le profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { fermer() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") { Task { await enregistrer() } }
                        .disabled(enregistre || brouillon.nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                brouillon = depart.edition
                catalogue = (try? await salon.outils.catalogue()) ?? []
            }
        }
    }

    private func enregistrer() async {
        enregistre = true
        defer { enregistre = false }
        do {
            if let id = depart.id { _ = try await salon.profils.modifier(id, brouillon) } else { _ = try await salon.profils.creer(brouillon) }
            await apres()
            fermer()
        } catch {
            erreur = Salon.libelle(error)
        }
    }
}
#endif
