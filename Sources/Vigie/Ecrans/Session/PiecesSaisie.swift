// Le « + » du composeur, comme l'étalon : photothèque, appareil photo, fichiers ; puis le mode de permission et la
// compaction. Les pièces (3 au plus, 3 Mio chacune, `pieces` du message) attendent en vignettes au-dessus du champ.
#if canImport(SwiftUI)
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VigieNoyau

struct PieceSaisie: Identifiable, Equatable, Sendable {
    let id = UUID()
    let piece: PieceJointe
    let apercu: UIImage?
}

/// Préparation des pièces, hors du fil principal : photo réduite en JPEG sous la limite, fichier lu tel quel.
enum PreparationPieces {
    enum Refus: Error { case tropGrand(String), illisible }

    static func photo(_ donnees: Data, nom: String) async throws -> PieceSaisie {
        try await Task.detached(priority: .userInitiated) {
            for cote in [2048, 1600, 1200] {
                guard let image = ModeleRelais.reduire(donnees, cote: cote),
                      let jpeg = image.jpegData(compressionQuality: 0.82) else { throw Refus.illisible }
                if jpeg.count <= PieceJointe.tailleMax {
                    let piece = PieceJointe(nom: nom, mime: "image/jpeg", base64: jpeg.base64EncodedString())
                    return PieceSaisie(piece: piece, apercu: ModeleRelais.reduire(jpeg, cote: 240))
                }
            }
            throw Refus.tropGrand(nom)
        }.value
    }

    static func fichier(_ url: URL) throws -> PieceSaisie {
        let acces = url.startAccessingSecurityScopedResource()
        defer { if acces { url.stopAccessingSecurityScopedResource() } }
        let donnees = try Data(contentsOf: url)
        guard donnees.count <= PieceJointe.tailleMax else { throw Refus.tropGrand(url.lastPathComponent) }
        let type = UTType(filenameExtension: url.pathExtension)
        let mime = type?.preferredMIMEType ?? "application/octet-stream"
        let apercu = type?.conforms(to: .image) == true ? ModeleRelais.reduire(donnees, cote: 240) : nil
        let piece = PieceJointe(nom: url.lastPathComponent, mime: mime, base64: donnees.base64EncodedString())
        return PieceSaisie(piece: piece, apercu: apercu)
    }

    static func message(_ erreur: Error) -> String {
        if case Refus.tropGrand(let nom) = erreur { return "« \(nom) » dépasse 3 Mo." }
        return "Pièce illisible."
    }
}

/// Les pièces en attente : vignette 56 pt (ou icône de fichier) et petite croix pour retirer.
struct BandePieces: View {
    @Binding var pieces: [PieceSaisie]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pieces) { p in vignette(p) }
            }
            .padding(.horizontal, 12)
        }
    }

    private func vignette(_ p: PieceSaisie) -> some View {
        Group {
            if let image = p.apercu {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "doc").font(.system(size: 18, weight: .light))
                    Text(p.piece.nom).font(.system(size: 10)).lineLimit(1)
                }
                .foregroundStyle(Q.secondaire).padding(4)
            }
        }
        .frame(width: 56, height: 56)
        .background(Q.rond)
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button { pieces.removeAll { $0.id == p.id } } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Q.carte)
                    .frame(width: 18, height: 18).background(Q.texte, in: .circle)
                    .frame(width: 32, height: 32, alignment: .topTrailing)
            }
            .offset(x: 6, y: -6)
            .accessibilityLabel("Retirer \(p.piece.nom)")
        }
    }
}

/// Le « + » : ajouter des photos, prendre une photo, joindre un fichier ; mode de permission ; compacter.
struct MenuPlus: View {
    @Environment(ModeleRelais.self) private var modele
    /// nil : nouvelle session (pièces seulement, pas encore de mode ni de compaction).
    let session: Session?
    @Binding var pieces: [PieceSaisie]
    var ouvrirUsage: () -> Void = {}
    var ouvrirTaches: () -> Void = {}
    let erreur: (String) -> Void
    @State private var phototheque = false
    @State private var choix: [PhotosPickerItem] = []
    @State private var camera = false
    @State private var fichiers = false

    private var place: Int { max(PieceJointe.nombreMax - pieces.count, 0) }

    var body: some View {
        Menu { contenu } label: {
            Image(systemName: "plus").font(.system(size: 17)).foregroundStyle(Q.texte)
                .frame(width: 36, height: 36).background(Q.rond, in: .circle).contentShape(.circle)
        }
        .accessibilityLabel("Ajouter")
        .photosPicker(isPresented: $phototheque, selection: $choix, maxSelectionCount: max(place, 1), matching: .images)
        .onChange(of: choix) { _, items in importer(items) }
        .fullScreenCover(isPresented: $camera) {
            Camera(prise: { donnees in camera = false; ajouterPhoto(donnees, nom: "photo.jpg") },
                   annuler: { camera = false })
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $fichiers, allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
            joindre(r)
        }
    }

    @ViewBuilder private var contenu: some View {
        Section {
            Button("Photos", systemImage: "photo.on.rectangle") { if verifierPlace() { phototheque = true } }
            Button("Appareil photo", systemImage: "camera") { if verifierPlace() { camera = true } }
            Button("Fichiers", systemImage: "paperclip") { if verifierPlace() { fichiers = true } }
        }
        if let session { reglages(session) }
    }

    @ViewBuilder private func reglages(_ session: Session) -> some View {
        Section {
            Picker("Permissions", systemImage: "hand.raised", selection: mode(session)) {
                ForEach(CatalogueModeles.modesPermission, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.menu)
            Button("Compacter le contexte", systemImage: "arrow.down.right.and.arrow.up.left") {
                Task { if let e = await modele.agir(.compacter, sur: session.id) { erreur(e) } }
            }
            Button("Tâches de fond", systemImage: "diamond", action: ouvrirTaches)
            Button("Usage", systemImage: "gauge.with.dots.needle.33percent", action: ouvrirUsage)
        }
    }

    private func verifierPlace() -> Bool {
        if place > 0 { return true }
        erreur("Trois pièces au plus par message.")
        return false
    }

    private func importer(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        choix = []
        for (i, item) in items.prefix(place).enumerated() {
            Task {
                guard let donnees = try? await item.loadTransferable(type: Data.self) else {
                    erreur("Photo illisible.")
                    return
                }
                ajouterPhoto(donnees, nom: "photo-\(i + 1).jpg")
            }
        }
    }

    private func ajouterPhoto(_ donnees: Data, nom: String) {
        Task {
            do {
                let p = try await PreparationPieces.photo(donnees, nom: nom)
                if pieces.count < PieceJointe.nombreMax { pieces.append(p) }
            } catch { erreur(PreparationPieces.message(error)) }
        }
    }

    private func joindre(_ r: Result<[URL], Error>) {
        guard case .success(let urls) = r else { return }
        for url in urls.prefix(place) {
            do { pieces.append(try PreparationPieces.fichier(url)) } catch { erreur(PreparationPieces.message(error)) }
        }
    }

    private func mode(_ session: Session) -> Binding<String> {
        Binding(get: { session.mode ?? ModeSession.bypassPermissions.rawValue }, set: { nouveau in
            Task { if let e = await modele.changerMode(nouveau, de: session.id) { erreur(e) } }
        })
    }
}

/// L'appareil photo système. `☠` Jamais dans un NavigationLink, jamais `dismiss` de l'environnement (skill swift-ios) :
/// présenté en plein écran, fermé par l'appelant via `prise` / `annuler`.
private struct Camera: UIViewControllerRepresentable {
    let prise: (Data) -> Void
    let annuler: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ c: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinateur { Coordinateur(prise: prise, annuler: annuler) }

    @MainActor final class Coordinateur: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let prise: (Data) -> Void
        let annuler: () -> Void

        init(prise: @escaping (Data) -> Void, annuler: @escaping () -> Void) {
            self.prise = prise
            self.annuler = annuler
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            if let donnees = image?.jpegData(compressionQuality: 0.9) { prise(donnees) } else { annuler() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { annuler() }
    }
}
#endif
