// Une image du fil (étalon : vignette arrondie, à droite quand elle vient de Chris, à gauche quand Claude la montre) ;
// toucher l'ouvre en plein écran, zoom par pincement, fermeture par la croix ou en glissant vers le bas.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// La session dont le fil est affiché, pour les vues qui chargent ses fichiers (images).
private struct CleSessionFil: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var sessionFil: String {
        get { self[CleSessionFil.self] }
        set { self[CleSessionFil.self] = newValue }
    }
}

struct ImageFil: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.sessionFil) private var session
    let fichier: String
    let nom: String
    let deChris: Bool
    @State private var image: UIImage?
    @State private var echec = false
    @State private var pleinEcran = false

    var body: some View {
        HStack {
            if deChris { Spacer(minLength: 64) }
            vignette
            if !deChris { Spacer(minLength: 64) }
        }
        .padding(.trailing, deChris ? -8 : 0)
        .task(id: fichier) { await charger() }
        .fullScreenCover(isPresented: $pleinEcran) { ImagePleinEcran(fichier: fichier, apercu: image) }
    }

    @ViewBuilder private var vignette: some View {
        if let image {
            Button { pleinEcran = true } label: {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 320)
                    .clipShape(.rect(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(StyleAppui())
            .accessibilityLabel(nom)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Q.carte).frame(width: 160, height: 120)
                .overlay {
                    if echec {
                        Label("Image indisponible", systemImage: "photo").font(Q.petit).foregroundStyle(Q.tertiaire)
                    } else {
                        IndicateurTravail().frame(width: 16, height: 16)
                    }
                }
        }
    }

    private func charger() async {
        guard image == nil, !session.isEmpty else { return }
        image = await modele.vignette(fichier, de: session)
        echec = image == nil
    }
}

private struct ImagePleinEcran: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.sessionFil) private var session
    @Environment(\.dismiss) private var fermer
    let fichier: String
    let apercu: UIImage?
    @State private var image: UIImage?
    @State private var echelle: CGFloat = 1
    @State private var glisse: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(1 - min(abs(glisse) / 400, 0.6)).ignoresSafeArea()
            if let affichee = image ?? apercu {
                Image(uiImage: affichee).resizable().scaledToFit()
                    .scaleEffect(echelle).offset(y: glisse)
                    .gesture(MagnifyGesture().onChanged { echelle = max(1, $0.magnification) }
                        .onEnded { _ in withAnimation(.smooth) { if echelle < 1.1 { echelle = 1 } } })
                    .simultaneousGesture(DragGesture().onChanged { if echelle == 1 { glisse = $0.translation.height } }
                        .onEnded(finGlisse))
                    .onTapGesture(count: 2) { withAnimation(.smooth) { echelle = echelle > 1 ? 1 : 2.5 } }
            }
            BoutonEntete(symbole: "xmark") { fermer() }.padding(.top, 8).padding(.trailing, 8)
        }
        .task { image = await modele.original(fichier, de: session) }
    }

    private func finGlisse(_ g: DragGesture.Value) {
        if abs(g.translation.height) > 120 { fermer() } else { withAnimation(.smooth) { glisse = 0 } }
    }
}
#endif
