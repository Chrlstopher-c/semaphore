// Un dossier d'un appareil du parc : parcourir, ouvrir un fichier, créer un dossier, déposer des fichiers ou des
// photos du téléphone, renommer, supprimer, ouvrir un terminal ici. Tout passe par le relais (4G comprise).
#if canImport(SwiftUI)
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VigieNoyau

struct EmplacementDistant: Hashable {
    let machine: String
    let chemin: String?
}

struct DossierEcran: View {
    @Environment(ModeleRelais.self) private var modele
    let lieu: EmplacementDistant
    @State private var liste: ListeDossier?
    @State private var erreur: String?
    @State private var caches = false
    @State private var envoi: String?
    @State private var importer = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var saisie: Saisie?
    @State private var aSupprimer: EntreeFichier?

    var body: some View {
        List {
            if let erreur { Text(erreur).foregroundStyle(.red).font(.footnote) }
            if let envoi { Label(envoi, systemImage: "arrow.up.circle").foregroundStyle(.secondary) }
            ForEach(visibles) { ligne($0) }
        }
        .overlay { if liste == nil && erreur == nil { ProgressView() } }
        .navigationTitle(liste.map { CheminDistant.nom($0.chemin) } ?? lieu.machine)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { menu }
        .refreshable { await charger() }
        .task { await charger() }
        .fileImporter(isPresented: $importer, allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
            if case .success(let urls) = r { Task { await deposer(urls) } }
        }
        .photosPicker(isPresented: Binding(get: { saisie == .photos }, set: { if !$0 { saisie = nil } }),
                      selection: $photos, matching: .any(of: [.images, .videos]))
        .onChange(of: photos) { _, choisies in Task { await deposer(choisies) } }
        .alert(saisie?.titre ?? "", isPresented: Binding(get: { saisie?.demandeNom == true },
                                                          set: { if !$0 { saisie = nil } })) { alerteNom }
        .confirmationDialog("Supprimer \(aSupprimer?.nom ?? "") ?", isPresented: Binding(
            get: { aSupprimer != nil }, set: { if !$0 { aSupprimer = nil } }), titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { if let e = aSupprimer { Task { await supprimer(e) } } }
        } message: { Text(aSupprimer?.type == .dossier ? "Le dossier et tout son contenu." : "Définitivement.") }
    }

    private var visibles: [EntreeFichier] {
        (liste?.entrees ?? []).filter { caches || !$0.cache }
    }

    @ViewBuilder private func ligne(_ e: EntreeFichier) -> some View {
        let chemin = CheminDistant.joindre(liste?.chemin ?? "", e.nom)
        Group {
            if e.type == .dossier {
                NavigationLink(value: EmplacementDistant(machine: lieu.machine, chemin: chemin)) { LigneFichier(e: e) }
            } else {
                NavigationLink(value: FichierDistant(machine: lieu.machine, chemin: chemin, taille: e.taille)) {
                    LigneFichier(e: e)
                }
            }
        }
        .swipeActions {
            Button("Supprimer", systemImage: "trash", role: .destructive) { aSupprimer = e }
            Button("Renommer", systemImage: "pencil") { saisie = .renommer(e.nom, e.nom) }.tint(.orange)
        }
    }

    @ToolbarContentBuilder private var menu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu("Actions", systemImage: "ellipsis.circle") {
                Button("Déposer des fichiers", systemImage: "doc.badge.plus") { importer = true }
                Button("Déposer des photos", systemImage: "photo.badge.plus") { saisie = .photos }
                Button("Nouveau dossier", systemImage: "folder.badge.plus") { saisie = .dossier("") }
                if let chemin = liste?.chemin {
                    NavigationLink(value: CibleTerminal(machine: lieu.machine, dossier: chemin,
                                                        titre: "\(lieu.machine) · \(CheminDistant.nom(chemin))")) {
                        Label("Terminal ici", systemImage: "apple.terminal")
                    }
                }
                Toggle("Fichiers cachés", systemImage: "eye", isOn: $caches)
            }
        }
    }

    @ViewBuilder private var alerteNom: some View {
        TextField("Nom", text: Binding(get: { saisie?.nom ?? "" }, set: { saisie = saisie?.avec(nom: $0) }))
            .autocorrectionDisabled().textInputAutocapitalization(.never)
        Button("Annuler", role: .cancel) { saisie = nil }
        Button("Valider") { if let s = saisie { Task { await valider(s) } } }
    }

    // MARK: - Actions

    private var client: ClientRelais? { modele.client }

    private func charger() async {
        guard let client else { return }
        do {
            liste = try await client.lire(Route.fichiers(lieu.machine, chemin: liste?.chemin ?? lieu.chemin))
            erreur = nil
        } catch {
            erreur = "\(error)"
        }
    }

    private func agir(_ action: () async throws -> Void) async {
        do {
            try await action()
            await charger()
        } catch {
            erreur = "\(error)"
        }
    }

    private func valider(_ s: Saisie) async {
        guard let client, let dossier = liste?.chemin, !s.nom.isEmpty else { return }
        saisie = nil
        await agir {
            switch s {
            case .dossier(let nom):
                try await client.ecrire(Route.creerDossier(lieu.machine), CorpsChemin(chemin: CheminDistant.joindre(dossier, nom)))
            case .renommer(let ancien, let nom):
                try await client.ecrire(Route.renommer(lieu.machine), CorpsRenommer(
                    de: CheminDistant.joindre(dossier, ancien), vers: CheminDistant.joindre(dossier, nom)))
            case .photos: break
            }
        }
    }

    private func supprimer(_ e: EntreeFichier) async {
        guard let client, let dossier = liste?.chemin else { return }
        aSupprimer = nil
        await agir {
            try await client.ecrire(Route.supprimer(lieu.machine), CorpsChemin(chemin: CheminDistant.joindre(dossier, e.nom)))
        }
    }

    private func deposer(_ urls: [URL]) async {
        await agir {
            for url in urls {
                let acces = url.startAccessingSecurityScopedResource()
                defer { if acces { url.stopAccessingSecurityScopedResource() } }
                try await envoyer(url.lastPathComponent, try Data(contentsOf: url))
            }
        }
    }

    private func deposer(_ choisies: [PhotosPickerItem]) async {
        guard !choisies.isEmpty else { return }
        photos = []
        await agir {
            for (i, item) in choisies.enumerated() {
                guard let donnees = try await item.loadTransferable(type: Data.self) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                try await envoyer("\(Self.horodatage())-\(i + 1).\(ext)", donnees)
            }
        }
    }

    private func envoyer(_ nom: String, _ donnees: Data) async throws {
        guard let client, let dossier = liste?.chemin else { return }
        envoi = "Envoi de \(nom) (\(Format.octets(Double(donnees.count))))…"
        defer { envoi = nil }
        try await client.deposer(Route.fichier(lieu.machine, chemin: CheminDistant.joindre(dossier, nom)), donnees)
    }

    private static func horodatage() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return "photo-" + f.string(from: Date())
    }
}

/// Ce que l'écran demande à l'utilisateur : un nom (nouveau dossier, renommage) ou des photos.
private enum Saisie: Equatable {
    case dossier(String)
    case renommer(String, String)
    case photos

    var nom: String {
        switch self {
        case .dossier(let n), .renommer(_, let n): return n
        case .photos: return ""
        }
    }

    var demandeNom: Bool { self != .photos }
    var titre: String { if case .renommer = self { return "Renommer" } else { return "Nouveau dossier" } }

    func avec(nom: String) -> Saisie {
        switch self {
        case .dossier: return .dossier(nom)
        case .renommer(let ancien, _): return .renommer(ancien, nom)
        case .photos: return self
        }
    }
}

private struct LigneFichier: View {
    let e: EntreeFichier

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbole).foregroundStyle(e.type == .dossier ? Charte.accent : .secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.nom).lineLimit(1).truncationMode(.middle).opacity(e.cache ? 0.6 : 1)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var detail: String {
        let date = Format.depuis(e.modifie)
        return e.type == .dossier ? date : "\(Format.octets(e.taille)) · \(date)"
    }

    private var symbole: String {
        switch e.type {
        case .dossier: return "folder.fill"
        case .lien: return "link"
        case .autre: return "questionmark.square.dashed"
        case .fichier:
            switch ApercuFichier.de(e.nom) {
            case .image: return "photo"
            case .texte: return "doc.text"
            case .markdown: return "doc.richtext"
            case .quickLook: return "doc"
            }
        }
    }
}
#endif
