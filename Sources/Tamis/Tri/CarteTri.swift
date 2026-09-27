// La carte du tri rapide : la photo en grand, sa date et son poids. Elle se
// teinte pendant le glissé — rouge vers la gauche, citron vers la droite — pour
// que le verdict se lise avant d'être rendu.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct CarteTri: View {
    let cliche: Cliche
    /// Déplacement horizontal en cours, 0 au repos.
    let glisse: CGFloat
    @State private var image: UIImage?

    private var elan: CGFloat { min(abs(glisse) / Trame.seuilGlisse, 1) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Neutre.surface
            if let image {
                Image(uiImage: image).resizable().scaledToFit().transition(.opacity)
            } else {
                ProgressView().tint(Neutre.encreEteinte).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            legende
        }
        .clipShape(.rect(cornerRadius: Rayon.carte, style: .continuous))
        .lisere()
        .overlay { verdict }
        .task(id: cliche.id) {
            let lue = await Images.image(cliche.id, cote: 1_080, reseau: true)
            withAnimation(Mouvement.micro) { image = lue }
        }
    }

    private var legende: some View {
        HStack(spacing: Grille.serre) {
            if cliche.media == .video { Image(systemName: "video.fill") }
            Text(Legende.de(cliche))
        }
        .font(Voix.mesure)
        .foregroundStyle(Neutre.encre)
        .padding(.horizontal, Grille.element)
        .padding(.vertical, Grille.serre)
        .background(Neutre.fond.opacity(0.7), in: .capsule)
        .padding(Grille.element)
    }

    @ViewBuilder private var verdict: some View {
        let part = glisse < 0
        RoundedRectangle(cornerRadius: Rayon.carte, style: .continuous)
            .fill((part ? Teinte.depart : Teinte.accent).opacity(0.25 * elan))
            .overlay {
                Image(systemName: part ? "trash.fill" : "heart.fill")
                    .font(.system(.largeTitle, weight: .semibold))
                    .foregroundStyle(part ? Teinte.depart : Teinte.accent)
                    .opacity(elan)
                    .scaleEffect(0.8 + 0.2 * elan)
            }
            .allowsHitTesting(false)
    }
}
#endif
