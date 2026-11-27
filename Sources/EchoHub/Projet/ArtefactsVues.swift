// Les artefacts de l'agent (`CarteVersionArtefact`, `CarteArtefact`, `PanneauArtefact` du web) : une carte dans le
// fil, et une feuille qui montre la version choisie en aperçu (HTML, SVG, Markdown) ou en code.
#if canImport(SwiftUI) && canImport(WebKit)
import SwiftUI
import WebKit
import EchoHubNoyau

/// La carte d'une version créée : ouvre la feuille sur CETTE version.
struct CarteVersionArtefact: View {
    let version: VersionArtefact
    @State private var ouverte = false

    var body: some View {
        CarteFichier(titre: version.titre, detail: "Artefact · \(version.type) · v\(version.version)",
                     symbole: "rectangle.on.rectangle") { ouverte = true }
            .sheet(isPresented: $ouverte) { ArtefactFeuille(depart: version) }
    }
}

/// La carte d'un fichier présenté par l'agent.
struct CarteFichierPresente: View {
    let fichier: FichierPresente
    @State private var ouverte = false

    var body: some View {
        CarteFichier(titre: fichier.nomAffiche, detail: "\(fichier.typeMime) · \(Self.taille(fichier.tailleOctets))",
                     symbole: fichier.estImage ? "photo" : "doc") { ouverte = true }
            .sheet(isPresented: $ouverte) { FichierPresenteFeuille(fichier: fichier) }
    }

    static func taille(_ octets: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(octets), countStyle: .file)
    }
}

private struct CarteFichier: View {
    let titre: String
    let detail: String
    let symbole: String
    let ouvrir: () -> Void

    var body: some View {
        Button(action: ouvrir) {
            HStack(spacing: Trame.element) {
                Image(systemName: symbole).foregroundStyle(Teinte.accent).frame(width: 20)
                VStack(alignment: .leading, spacing: Trame.fin) {
                    Text(titre).mention().foregroundStyle(Teinte.encre).lineLimit(1)
                    Text(detail).mesureFine().foregroundStyle(Teinte.encreDouce)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Teinte.encreEteinte)
            }
            .padding(Trame.element)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Teinte.surface)
            .clipShape(.rect(cornerRadius: Galbe.carte, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Galbe.carte, style: .continuous).strokeBorder(Teinte.trait))
        }
        .buttonStyle(.appui)
    }
}

/// La feuille d'un artefact : versions du fil affiché, interrupteur Aperçu / Code.
struct ArtefactFeuille: View {
    let depart: VersionArtefact
    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @State private var numero: Int?
    @State private var apercu = true
    @State private var contenu: EtatChargement<String> = .chargement

    private var versions: [VersionArtefact] {
        let contenus = salon.messages.filter { $0.role == .assistant }.map(\.contenu) + (salon.enCours.map { [$0.texte] } ?? [])
        return Artefacts.catalogue(contenus).first { $0.artefactId == depart.artefactId }?.versions ?? [depart]
    }

    private var courante: VersionArtefact {
        versions.first { $0.version == (numero ?? depart.version) } ?? depart
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Vue", selection: $apercu) {
                    Text("Aperçu").tag(true)
                    Text("Code").tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(!courante.apercuPossible)
                .padding(Trame.ecran)
                RenduContenu(etat: contenu, type: courante.apercuPossible && apercu ? courante.type : "code")
            }
            .background(Teinte.fond)
            .navigationTitle(courante.titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Fermer") { fermer() } }
                if versions.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("v\(courante.version)") {
                            ForEach(versions, id: \.version) { version in
                                Button("Version \(version.version)") { numero = version.version }
                            }
                        }
                    }
                }
            }
            .task(id: courante.fichierId) { contenu = await Self.lire(courante.fichierId, salon: salon) }
        }
    }

    static func lire(_ fichierId: String, salon: Salon) async -> EtatChargement<String> {
        do {
            let donnees = try await salon.client.contenuFichier(fichierId)
            return .pret(String(decoding: donnees, as: UTF8.self))
        } catch {
            return .echec(Salon.libelle(error))
        }
    }
}

/// Un fichier présenté : image affichée, HTML rendu, le reste en texte.
struct FichierPresenteFeuille: View {
    let fichier: FichierPresente
    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @State private var donnees: EtatChargement<Data> = .chargement

    var body: some View {
        NavigationStack {
            Group {
                switch donnees {
                case .chargement, .vide: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .echec(let message): Text(message).foregroundStyle(Teinte.panne).padding(Trame.ecran)
                case .pret(let octets):
                    if fichier.estImage, let image = UIImage(data: octets) {
                        ScrollView([.horizontal, .vertical]) { Image(uiImage: image) }
                    } else {
                        RenduContenu(etat: .pret(String(decoding: octets, as: UTF8.self)), type: fichier.estHtml ? "html" : "code")
                    }
                }
            }
            .background(Teinte.fond)
            .navigationTitle(fichier.nomAffiche)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Fermer") { fermer() } } }
            .task {
                do { donnees = .pret(try await salon.client.contenuFichier(fichier.fichierId)) }
                catch { donnees = .echec(Salon.libelle(error)) }
            }
        }
    }
}

private struct RenduContenu: View {
    let etat: EtatChargement<String>
    let type: String

    var body: some View {
        switch etat {
        case .chargement, .vide:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .echec(let message):
            Text(message).foregroundStyle(Teinte.panne).padding(Trame.ecran).frame(maxHeight: .infinity, alignment: .top)
        case .pret(let texte):
            switch type {
            case "html": PageHtml(html: texte)
            case "svg": PageHtml(html: Artefacts.pageSvg(texte))
            case "markdown": ScrollView { RenduMarkdown(source: texte).padding(Trame.ecran) }
            default:
                ScrollView([.vertical, .horizontal]) {
                    Text(texte).font(.system(size: 12, design: .monospaced)).foregroundStyle(Teinte.encre)
                        .textSelection(.enabled).padding(Trame.ecran)
                }
            }
        }
    }
}

/// Une page HTML hors réseau, comme l'iframe `srcdoc` du web : aucun accès à l'EchoHub ni au jeton.
private struct PageHtml: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let vue = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        vue.loadHTMLString(html, baseURL: nil)
        return vue
    }

    func updateUIView(_ vue: WKWebView, context: Context) {
        vue.loadHTMLString(html, baseURL: nil)
    }
}
#endif
