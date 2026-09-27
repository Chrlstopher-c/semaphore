// Une vignette de la photothèque, et son marquage de verdict : rouge barré au
// panier, point citron si gardée. Rien d'autre ne s'y peint.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct Vignette: View {
    let id: String
    /// En pixels.
    var cote: CGFloat = 240
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Neutre.surface)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill().transition(.opacity)
                }
            }
            .clipped()
            .task(id: id) {
                let lue = await Images.image(id, cote: cote, reseau: false)
                withAnimation(Mouvement.micro) { image = lue }
            }
    }
}

/// Une case de grille : vignette carrée, verdict, pastille vidéo.
struct CaseCliche: View {
    let cliche: Cliche
    let auPanier: Bool
    let garde: Bool

    var body: some View {
        Vignette(id: cliche.id)
            .aspectRatio(1, contentMode: .fit)
            .overlay { if auPanier { Teinte.depart.opacity(0.35) } }
            .overlay(alignment: .topTrailing) { marque.padding(Grille.fin) }
            .overlay(alignment: .bottomLeading) { duree.padding(Grille.fin) }
            .scaleEffect(auPanier ? 0.92 : 1)
            .animation(Mouvement.micro, value: auPanier)
            .accessibilityLabel(auPanier ? "Au panier" : garde ? "Gardée" : "À trier")
    }

    @ViewBuilder private var marque: some View {
        if auPanier {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Neutre.encre, Teinte.depart)
        } else if garde {
            Circle().fill(Teinte.accent).frame(width: Grille.serre, height: Grille.serre)
        }
    }

    @ViewBuilder private var duree: some View {
        if cliche.media == .video {
            Text(Duree.courte(cliche.duree))
                .font(Voix.mesure)
                .foregroundStyle(Neutre.encre)
                .shadow(color: .black.opacity(0.6), radius: 2)
        }
    }
}

enum Duree {
    /// 75 → « 1:15 ».
    static func courte(_ secondes: Double) -> String {
        let total = Int(secondes.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
#endif
