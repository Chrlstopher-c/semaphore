// Un fichier d'un appareil du parc : l'image s'affiche (zoom), le texte et le code s'éditent et s'enregistrent,
// le Markdown se lit mis en forme, le reste (PDF, vidéo, son, documents) s'ouvre dans QuickLook. Partage natif.
#if canImport(SwiftUI)
import QuickLook
import SwiftUI
import VigieNoyau

struct FichierDistant: Hashable {
    let machine: String
    let chemin: String
    let taille: Double
}

struct FichierEcran: View {
    @Environment(ModeleRelais.self) private var modele
    let fichier: FichierDistant
    @State private var local: URL?
    @State private var texte = ""
    @State private var original = ""
    @State private var lisible = false
    @State private var apercuMarkdown = true
    @State private var erreur: String?
    @State private var enregistrement = false
    @State private var confirmerGros = false

    private let tailleSansDemander: Double = 25 * 1024 * 1024
    private var nom: String { CheminDistant.nom(fichier.chemin) }
    private var genre: ApercuFichier { ApercuFichier.de(nom) }

    var body: some View {
        contenu
            .navigationTitle(nom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barre }
            .task { if fichier.taille <= tailleSansDemander { await charger() } else { confirmerGros = true } }
    }

    @ViewBuilder private var contenu: some View {
        if let erreur {
            ContentUnavailableView("Ouverture impossible", systemImage: "exclamationmark.triangle", description: Text(erreur))
        } else if confirmerGros {
            ContentUnavailableView {
                Label("Fichier volumineux", systemImage: "arrow.down.circle")
            } description: {
                Text("\(Format.octets(fichier.taille)) à télécharger sur le téléphone.")
            } actions: {
                Button("Télécharger") { confirmerGros = false; Task { await charger() } }.buttonStyle(.borderedProminent)
            }
        } else if let local {
            vue(local)
        } else {
            ProgressView("Chargement…")
        }
    }

    @ViewBuilder private func vue(_ local: URL) -> some View {
        if genre == .image, let image = UIImage(contentsOfFile: local.path) {
            ImageZoomable(image: image)
        } else if genre.editable && lisible {
            if genre == .markdown && apercuMarkdown {
                ScrollView { Text(markdown).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
            } else {
                TextEditor(text: $texte)
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
            }
        } else {
            ApercuQuickLook(url: local).ignoresSafeArea(edges: .bottom)
        }
    }

    private var markdown: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: texte, options: options)) ?? AttributedString(texte)
    }

    @ToolbarContentBuilder private var barre: some ToolbarContent {
        if genre == .markdown && lisible {
            ToolbarItem(placement: .secondaryAction) {
                Toggle("Aperçu", systemImage: "eye", isOn: $apercuMarkdown)
            }
        }
        if genre.editable && lisible && texte != original {
            ToolbarItem(placement: .confirmationAction) {
                Button(enregistrement ? "…" : "Enregistrer") { Task { await enregistrer() } }.bold().disabled(enregistrement)
            }
        }
        if let local {
            ToolbarItem(placement: .primaryAction) { ShareLink(item: local) }
        }
    }

    private func charger() async {
        guard let client = modele.client else { return }
        do {
            let donnees = try await client.telecharger(Route.fichier(fichier.machine, chemin: fichier.chemin))
            let url = FileManager.default.temporaryDirectory.appending(path: "acces-\(fichier.machine)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let cible = url.appending(path: nom)
            try donnees.write(to: cible, options: .atomic)
            if genre.editable, Double(donnees.count) <= ApercuFichier.tailleMaxEdition, let t = String(data: donnees, encoding: .utf8) {
                texte = t
                original = t
                lisible = true
            }
            local = cible
        } catch {
            erreur = "\(error)"
        }
    }

    private func enregistrer() async {
        guard let client = modele.client else { return }
        enregistrement = true
        defer { enregistrement = false }
        do {
            try await client.deposer(Route.fichier(fichier.machine, chemin: fichier.chemin), Data(texte.utf8))
            original = texte
            if let local { try? Data(texte.utf8).write(to: local, options: .atomic) }
        } catch {
            erreur = "Enregistrement refusé : \(error)"
        }
    }
}

private struct ImageZoomable: View {
    let image: UIImage
    @State private var echelle: CGFloat = 1
    @GestureState private var pince: CGFloat = 1

    var body: some View {
        GeometryReader { g in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: g.size.width * echelle * pince, height: g.size.height * echelle * pince)
            }
            .gesture(MagnifyGesture().updating($pince) { v, s, _ in s = v.magnification }
                .onEnded { echelle = min(max(echelle * $0.magnification, 1), 6) })
            .onTapGesture(count: 2) { withAnimation { echelle = echelle > 1 ? 1 : 2.5 } }
        }
        .background(Color.black)
    }
}

/// QuickLook : PDF, vidéo, son, documents bureautiques… tout ce que l'iPhone sait montrer.
private struct ApercuQuickLook: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController()
        c.dataSource = context.coordinator
        return c
    }

    func updateUIViewController(_ c: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Source { Source(url: url) }

    final class Source: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
#endif
