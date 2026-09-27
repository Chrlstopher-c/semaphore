// La grille commune : quatre colonnes, un filet entre les cases. Toucher une
// case bascule son passage au panier ; l'appui long ouvre l'aperçu natif.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct GrilleVignettes: View {
    @Environment(Atelier.self) private var atelier
    let ids: [String]

    private let colonnes = Array(
        repeating: GridItem(.flexible(), spacing: Trame.jointure), count: Trame.colonnes
    )

    var body: some View {
        LazyVGrid(columns: colonnes, spacing: Trame.jointure) {
            ForEach(ids, id: \.self) { id in
                if let cliche = atelier.index[id] { case_(cliche) }
            }
        }
        .sensoryFeedback(Toucher.selection, trigger: atelier.decisions.panier.count)
    }

    private func case_(_ cliche: Cliche) -> some View {
        Button { atelier.basculerPanier(cliche.id) } label: {
            CaseCliche(
                cliche: cliche,
                auPanier: atelier.decisions.panier.contains(cliche.id),
                garde: atelier.decisions.gardes.contains(cliche.id)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Garder", systemImage: "heart") { atelier.garder([cliche.id]) }
            Button("Oublier le verdict", systemImage: "arrow.uturn.backward") { atelier.oublier([cliche.id]) }
        } preview: {
            Apercu(cliche: cliche)
        }
    }
}

/// L'aperçu d'appui long : l'image entière et ce qu'elle pèse.
struct Apercu: View {
    let cliche: Cliche
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            ZStack {
                Neutre.surface
                if let image { Image(uiImage: image).resizable().scaledToFit() }
            }
            .frame(width: Trame.apercu, height: Trame.apercu)
            Text(Legende.de(cliche)).font(Voix.mesure).foregroundStyle(Neutre.encreDouce)
                .padding([.horizontal, .bottom], Grille.element)
        }
        .background(Neutre.surface)
        .task { image = await Images.image(cliche.id, cote: 960, reseau: true) }
    }
}

enum Legende {
    /// « 14 mars 2019 · 3,2 Mo »
    static func de(_ cliche: Cliche) -> String {
        let date = cliche.date?.formatted(date: .long, time: .omitted) ?? "Sans date"
        let poids = cliche.poids.map(Octets.lisible) ?? "poids inconnu"
        return "\(date) · \(poids)"
    }
}
#endif
