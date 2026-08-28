// Vignette d'une pièce jointe déjà servie par le Pi.
//
// `☠` `PieceJointeApi.url` est LA SEULE route du contrat qui rend des octets,
// protégée par cookie de session (`ClientPi.octets`). Un `AsyncImage` nu
// échouerait dessus — d'où ce chargeur qui passe par le client unique.
#if canImport(SwiftUI)
import SwiftUI
import UIKit
import VigieNoyau

struct VignettePieceDistante: View {
    let piece: PieceJointeApi
    @Environment(\.clientPi) private var client

    @State private var octets: Data?
    @State private var echec = false
    @State private var visionneuse = false

    private var estImage: Bool { piece.type.hasPrefix("image/") }

    var body: some View {
        Button {
            guard octets != nil || !estImage else { return }
            visionneuse = true
        } label: {
            apercu
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                        .strokeBorder(Teinte.filetAppuye, lineWidth: Trame.trait)
                )
        }
        .buttonStyle(.allureCarte)
        .task { await charger() }
        .fullScreenCover(isPresented: $visionneuse) {
            VisionneusePieceEcran(piece: piece, octetsDejaCharges: octets)
        }
        .accessibilityLabel("Pièce jointe \(piece.nom)")
    }

    @ViewBuilder private var apercu: some View {
        if estImage, let octets, let image = UIImage(data: octets) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if echec || !estImage {
            tuileDocument
        } else {
            SilhouetteAttente(lignes: [0.8, 0.6])
        }
    }

    private var tuileDocument: some View {
        VStack(spacing: Trame.fin) {
            Image(systemName: "doc.fill")
                .font(.system(size: 16))
                .foregroundStyle(Teinte.encreTernie)
            Text(piece.nom)
                .donneeMinuscule()
                .foregroundStyle(Teinte.encreTernie)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Teinte.fondCreux)
    }

    /// Ne charge les octets que pour une image : un PDF n'a besoin d'être
    /// récupéré qu'à l'ouverture de la visionneuse, pas pour la vignette.
    private func charger() async {
        guard estImage, octets == nil else { return }
        switch await client.octets(piece.url) {
        case .success(let donnees): octets = donnees
        case .failure: echec = true
        }
    }
}
#endif
