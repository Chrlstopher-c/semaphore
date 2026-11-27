// La feuille Projet (`ModaleProjet.tsx` + `SectionApercu.tsx` du web) : le dossier de travail confié à la
// conversation — choisir, créer, retirer —, ses instantanés à restaurer, l'aperçu de l'app que l'agent fait
// tourner, et l'interrupteur « Haiku écrit le code ».
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct ProjetFeuille: View {
    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @State private var catalogue: CatalogueProjets?
    @State private var instantanes: [Instantane] = []
    @State private var apercu: EtatApercu?
    @State private var hybride = false
    @State private var nouveauNom = ""
    @State private var echec: String?
    @State private var aRestaurer: Instantane?
    @State private var confirmationFinale = false
    @State private var apercuOuvert: URLRequest?

    private var projet: String? { salon.conversation?.projet }

    var body: some View {
        NavigationStack {
            Form {
                if let echec {
                    Section { Text(echec).foregroundStyle(Teinte.panne) }
                }
                sectionLiaison
                if projet != nil {
                    sectionApercu
                    sectionInstantanes
                }
                sectionProjets
            }
            .scrollContentBackground(.hidden)
            .background(Teinte.fond)
            .navigationTitle("Projet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { fermer() } } }
            .task { await charger() }
            .refreshable { await charger() }
            .confirmationDialog(
                "Restaurer « \(aRestaurer?.message ?? "") » ?", isPresented: restaurationDemandee,
                titleVisibility: .visible
            ) {
                Button("Restaurer", role: .destructive) { confirmationFinale = true }
            } message: {
                Text("Les fichiers du projet reviennent à cet instantané.")
            }
            .alert("Vraiment restaurer ?", isPresented: $confirmationFinale) {
                Button("Restaurer", role: .destructive) { Task { await restaurer() } }
                Button("Annuler", role: .cancel) { aRestaurer = nil }
            } message: {
                Text("Ce qui a été écrit depuis sera remplacé sur le disque du PC.")
            }
            .sheet(item: apercuPresente) { requete in ApercuFeuille(requete: requete.valeur) }
        }
    }

    // MARK: - Sections

    private var sectionLiaison: some View {
        Section {
            HStack {
                Label(projet ?? "Aucun projet", systemImage: "folder")
                    .foregroundStyle(projet == nil ? Teinte.encreDouce : Teinte.encre)
                Spacer()
                if projet != nil {
                    Button("Retirer", role: .destructive) { Task { await lier(nil) } }
                }
            }
            Toggle("Haiku écrit le code", isOn: Binding(get: { hybride }, set: { neuf in
                Task { await changerHybride(neuf) }
            }))
            .tint(Teinte.accent)
        } header: {
            Text("Cette conversation")
        } footer: {
            Text("En hybride, le modèle local pilote et Claude Haiku écrit le code sans rien voir du projet.")
        }
    }

    private var sectionApercu: some View {
        Section("Aperçu") {
            if let apercu, !apercu.ports.isEmpty {
                ForEach(apercu.ports, id: \.self) { port in
                    Button {
                        Task { await pointer(port) }
                    } label: {
                        HStack {
                            Text("Port \(String(port))")
                            Spacer()
                            if apercu.port == port { Image(systemName: "checkmark").foregroundStyle(Teinte.accent) }
                        }
                    }
                }
                Button("Ouvrir l'aperçu") { Task { await ouvrirApercu() } }.disabled(apercu.port == nil)
            } else {
                Text("Aucun serveur en écoute : l'agent en lance un avec « Processus de fond ».")
                    .foregroundStyle(Teinte.encreDouce)
            }
            Button("Actualiser") { Task { await chargerApercu() } }
        }
    }

    private var sectionInstantanes: some View {
        Section("Instantanés") {
            if instantanes.isEmpty {
                Text("Aucun instantané.").foregroundStyle(Teinte.encreDouce)
            }
            ForEach(instantanes) { instantane in
                Button { aRestaurer = instantane } label: {
                    VStack(alignment: .leading, spacing: Trame.fin) {
                        Text(instantane.message).foregroundStyle(Teinte.encre).lineLimit(2)
                        Text(Date(timeIntervalSince1970: instantane.date), format: .dateTime.day().month().hour().minute())
                            .font(.caption).foregroundStyle(Teinte.encreEteinte)
                    }
                }
            }
        }
    }

    private var sectionProjets: some View {
        Section {
            HStack {
                TextField("nouveau-projet", text: $nouveauNom)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Créer") { Task { await creer() } }
                    .disabled(!DepotProjets.nomValide(nouveauNom))
            }
            ForEach(catalogue?.projets ?? []) { candidat in
                Button { Task { await lier(candidat.nom) } } label: {
                    HStack {
                        Text(candidat.nom).foregroundStyle(Teinte.encre)
                        Spacer()
                        if candidat.nom == projet { Image(systemName: "checkmark").foregroundStyle(Teinte.accent) }
                    }
                }
            }
        } header: {
            Text("Projets")
        } footer: {
            if catalogue?.actif == false { Text("Le mode projet n'est pas configuré sur le PC.") }
            else { Text("Minuscules, chiffres, « . », « _ » et « - ».") }
        }
    }

    // MARK: - Actions

    private func charger() async {
        guard let conversation = salon.conversation else { return }
        await tenter {
            async let liste = salon.projets.lister()
            async let mode = salon.projets.hybride(conversation.id)
            catalogue = try await liste
            hybride = try await mode
        }
        await chargerProjet()
    }

    private func chargerProjet() async {
        guard let projet else { instantanes = []; apercu = nil; return }
        await tenter { instantanes = try await salon.projets.instantanes(projet) }
        await chargerApercu()
    }

    private func chargerApercu() async {
        guard let projet else { return }
        await tenter { apercu = try await salon.projets.apercu(projet) }
    }

    private func lier(_ nom: String?) async {
        guard let conversation = salon.conversation else { return }
        await tenter { salon.poser(projet: try await salon.projets.lier(conversation.id, projet: nom)) }
        await chargerProjet()
    }

    private func creer() async {
        let nom = nouveauNom
        await tenter {
            _ = try await salon.projets.creer(nom)
            nouveauNom = ""
            catalogue = try await salon.projets.lister()
        }
        await lier(nom)
    }

    private func changerHybride(_ actif: Bool) async {
        guard let conversation = salon.conversation else { return }
        await tenter { hybride = try await salon.projets.changerHybride(conversation.id, actif) }
    }

    private func pointer(_ port: Int) async {
        guard let projet else { return }
        await tenter { apercu = try await salon.projets.pointerApercu(projet, port: port) }
    }

    private func restaurer() async {
        guard let projet, let cible = aRestaurer else { return }
        aRestaurer = nil
        await tenter { try await salon.projets.restaurer(projet, instantane: cible.sha) }
        await chargerProjet()
    }

    /// Le relais du Pi traduit le port de l'atelier en port de la tour, et l'ouvre par le tunnel.
    private func ouvrirApercu() async {
        guard let port = apercu?.port else { return }
        do {
            apercuOuvert = try await salon.client.requeteApercu(atelier: port)
        } catch {
            echec = Salon.libelle(error)
        }
    }

    private func tenter(_ action: () async throws -> Void) async {
        do {
            try await action()
            echec = nil
        } catch {
            Journal.echec("feuille projet : \(error)")
            echec = Salon.libelle(error)
        }
    }

    // MARK: - Liaisons

    private var restaurationDemandee: Binding<Bool> {
        Binding(get: { aRestaurer != nil && !confirmationFinale }, set: { if !$0 && !confirmationFinale { aRestaurer = nil } })
    }

    private var apercuPresente: Binding<RequeteIdentifiee?> {
        Binding(get: { apercuOuvert.map(RequeteIdentifiee.init) }, set: { if $0 == nil { apercuOuvert = nil } })
    }
}

struct RequeteIdentifiee: Identifiable {
    let valeur: URLRequest
    var id: String { valeur.url?.absoluteString ?? "" }
}
#endif
