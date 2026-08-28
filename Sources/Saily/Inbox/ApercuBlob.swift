// L'aperçu d'un blob (image/vidéo) chargé depuis `GET /api/blobs/:name`.
//
// `☠` Cette route exige le jeton `Bearer` : `AsyncImage` ne peut donc PAS la
// servir (elle n'ajoute aucun en-tête). On passe par la besace, qui tient le
// client authentifié, et on décode les octets en `UIImage`. Une vidéo n'a pas
// d'aperçu décodable à peu de frais : on montre son glyphe, pas sa première
// image.
#if canImport(SwiftUI)
import SwiftUI
import SailyNoyau

struct ApercuBlob: View {
    @Environment(Boite.self) private var boite
    let nom: String
    let cote: CGFloat

    @State private var image: Image?
    @State private var echoue = false

    var body: some View {
        contenu
            .frame(width: cote, height: cote)
            .background(Teinte.surfaceHaute)
            .clipShape(.rect(cornerRadius: Galbe.controle, style: .continuous))
            .task(id: nom) { await charger() }
    }

    @ViewBuilder
    private var contenu: some View {
        if let image {
            image.resizable().scaledToFill()
        } else {
            Image(systemName: echoue ? "photo.badge.exclamationmark" : "photo")
                .foregroundStyle(Teinte.encreEteinte)
        }
    }

    private func charger() async {
        guard image == nil else { return }
        guard let octets = await boite.chargerBlob(nom) else {
            echoue = true
            return
        }
        #if canImport(UIKit)
        if let uiImage = UIImage(data: octets) {
            image = Image(uiImage: uiImage)
        } else {
            echoue = true
        }
        #endif
    }
}
#endif
