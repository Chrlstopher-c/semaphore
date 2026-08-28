// L'écran de capture : le geste central du monde. On balance ici tout ce qui
// vient — une note, un lien, une image, un fichier — et ça part vers le serveur,
// visible aussitôt dans la besace.
//
// `☠` Priorité de Chris : l'intuitivité. Un seul champ pour le texte, qui DEVINE
// s'il tient une note ou un lien (une URL seule → lien), plus deux gestes
// explicites pour une image ou un fichier. Pas de menu d'espèce à choisir à la
// main : l'app comprend ce qu'on lui donne.
#if canImport(SwiftUI)
import SwiftUI
import SailyNoyau
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

struct CaptureEcran: View {
    @Environment(Boite.self) private var boite
    let surCapture: () -> Void

    @State private var texte = ""
    @State private var tagsBruts = ""
    @State private var enCours = false
    @State private var importeFichier = false
    #if canImport(PhotosUI)
    @State private var choixPhoto: PhotosPickerItem?
    #endif

    var body: some View {
        ZStack {
            Teinte.fond.ignoresSafeArea()
            ScrollView { contenu }
        }
        .fileImporter(
            isPresented: $importeFichier, allowedContentTypes: [.item], allowsMultipleSelection: false
        ) { resultat in
            Task { await importer(resultat) }
        }
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: Trame.section) {
            Fronton("Capturer").padding(.top, Trame.serre)
            champTexte
            champTags
            gestes
            boutonCapturer
        }
        .padding(.vertical, Trame.groupe)
    }

    // MARK: - Champ texte

    private var champTexte: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.serre) {
                Text(estUnLien ? "Un lien" : "Une note").rubrique()
                TextEditor(text: $texte)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120, maxHeight: 260)
                    .corps()
                    .foregroundStyle(Teinte.encre)
                    .tint(Teinte.accent)
                if texte.isEmpty {
                    Text("Colle ou écris — une note, une URL, ce qui te passe par la tête.")
                        .note().foregroundStyle(Teinte.encreEteinte)
                }
            }
        }
        .padding(.horizontal, Trame.ecran)
    }

    private var champTags: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.serre) {
                Text("Tags").rubrique()
                TextField("séparés par des virgules", text: $tagsBruts)
                    .textFieldStyle(.plain)
                    .corps()
                    .foregroundStyle(Teinte.encre)
                    .tint(Teinte.accent)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.horizontal, Trame.ecran)
    }

    // MARK: - Gestes image / fichier

    private var gestes: some View {
        HStack(spacing: Trame.element) {
            #if canImport(PhotosUI)
            PhotosPicker(selection: $choixPhoto, matching: .any(of: [.images, .videos])) {
                GesteCapture(symbole: "photo.on.rectangle", titre: "Photo / vidéo")
            }
            .onChange(of: choixPhoto) { _, nouveau in
                Task { await importerPhoto(nouveau) }
            }
            #endif
            Button { importeFichier = true } label: {
                GesteCapture(symbole: "doc.badge.plus", titre: "Fichier")
            }
            .buttonStyle(.appui)
        }
        .padding(.horizontal, Trame.ecran)
    }

    private var boutonCapturer: some View {
        Button { Task { await capturerTexte() } } label: {
            if enCours {
                ProgressView().tint(Teinte.fond)
            } else {
                Text(estUnLien ? "Capturer le lien" : "Capturer la note")
            }
        }
        .buttonStyle(.engage)
        .disabled(texteCoupe.isEmpty || enCours)
        .padding(.horizontal, Trame.ecran)
        .sensoryFeedback(Retour.engage, trigger: enCours) { avant, apres in avant && !apres }
    }

    // MARK: - Actions

    private func capturerTexte() async {
        guard !texteCoupe.isEmpty else { return }
        enCours = true
        if estUnLien {
            await boite.capturerLien(texteCoupe, tags: tags)
        } else {
            await boite.capturerNote(texteCoupe, tags: tags)
        }
        enCours = false
        reinitialiser()
        surCapture()
    }

    #if canImport(PhotosUI)
    private func importerPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        enCours = true
        defer { enCours = false; choixPhoto = nil }
        guard let donnees = try? await item.loadTransferable(type: Data.self) else { return }
        let mime = item.supportedContentTypes.first?.preferredMIMEType ?? "application/octet-stream"
        let espece: EspeceItem = mime.hasPrefix("video") ? .video : .image
        let nom = "capture.\(item.supportedContentTypes.first?.preferredFilenameExtension ?? "bin")"
        await boite.capturerBlob(donnees, kind: espece, nomFichier: nom, typeMime: mime, tags: tags)
        reinitialiser()
        surCapture()
    }
    #endif

    private func importer(_ resultat: Result<[URL], Error>) async {
        guard case let .success(urls) = resultat, let url = urls.first else { return }
        enCours = true
        defer { enCours = false }
        let accede = url.startAccessingSecurityScopedResource()
        defer { if accede { url.stopAccessingSecurityScopedResource() } }
        guard let donnees = try? Data(contentsOf: url) else { return }
        let mime = typeMime(pour: url)
        await boite.capturerBlob(
            donnees, kind: .fichier, nomFichier: url.lastPathComponent, typeMime: mime, tags: tags
        )
        reinitialiser()
        surCapture()
    }

    // MARK: - Dérivé

    private var texteCoupe: String {
        texte.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Une URL seule (un seul « mot », schéma http/https) → lien. Sinon, note.
    private var estUnLien: Bool {
        let coupe = texteCoupe
        guard !coupe.contains(where: \.isWhitespace) else { return false }
        return coupe.hasPrefix("http://") || coupe.hasPrefix("https://")
    }

    private var tags: [String] {
        tagsBruts.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func typeMime(pour url: URL) -> String {
        #if canImport(UniformTypeIdentifiers)
        if let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType {
            return type
        }
        #endif
        return "application/octet-stream"
    }

    private func reinitialiser() {
        texte = ""
        tagsBruts = ""
    }
}

/// Le label d'un geste de capture (photo, fichier). Un type à part, et non une
/// méthode : les labels de `PhotosPicker` et de `Button` sont des fermetures
/// nonisolated, et appeler une méthode isolée `@MainActor` depuis là échoue en
/// concurrence stricte. Une `View` structurée s'y insère sans friction.
private struct GesteCapture: View {
    let symbole: String
    let titre: String

    var body: some View {
        HStack(spacing: Trame.serre) {
            Image(systemName: symbole)
            Text(titre).mention()
        }
        .foregroundStyle(Teinte.accent)
        .frame(maxWidth: .infinity, minHeight: Trame.cible)
        .background(Teinte.surface, in: .rect(cornerRadius: Galbe.controle, style: .continuous))
        .lisere(Galbe.controle)
    }
}
#endif
