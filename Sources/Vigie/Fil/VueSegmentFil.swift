// Rendu d'un `SegmentFil` — la brique que la conversation empile, dans
// l'ordre que `SegmentationFil.segmenter` a déjà tranché.
//
// Parti pris de la charte : la conversation est un DOCUMENT. Les tours de
// l'orchestrateur se lisent pleine largeur, sans bulle — on vient lire du
// markdown long, pas des SMS. Seules les interjections de Chris prennent une
// bulle, à droite, pour que l'attribution se voie d'un coup d'œil.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct VueSegmentFil: View {
    let segment: SegmentFil
    /// Croisement `PropositionApi` par identifiant, pour les segments `.mandat`.
    let propositionsConnues: [String: PropositionApi]

    var body: some View {
        switch segment {
        case .operateur(let message):
            VueMessageOperateur(message: message)
        case .tour(let tour):
            VueTourAgent(tour: tour)
        case .mandat(_, let proposition, let at):
            VueMandatFil(identifiant: proposition, at: at, connue: propositionsConnues[proposition])
        case .compaction(_, let resume, let at):
            VueCompaction(resume: resume, at: at)
        }
    }
}

/// L'interjection de Chris : bulle accent voilée, à droite, pièces au-dessus.
private struct VueMessageOperateur: View {
    let message: MessageOperateur

    var body: some View {
        VStack(alignment: .trailing, spacing: Trame.serre) {
            if !message.pieces.isEmpty { rangeePieces }
            Text(message.texte)
                .phrase()
                .foregroundStyle(Teinte.encre)
                .padding(.horizontal, Trame.element)
                .padding(.vertical, Trame.serre + 2)
                .background(
                    Teinte.accent.opacity(0.16),
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 16, bottomLeadingRadius: 16,
                        bottomTrailingRadius: 5, topTrailingRadius: 16,
                        style: .continuous
                    )
                )
            Text(heureFil(message.at))
                .donneeMinuscule()
                .foregroundStyle(Teinte.encreTernie)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 44)
    }

    private var rangeePieces: some View {
        HStack(spacing: Trame.serre) {
            Spacer(minLength: 0)
            ForEach(message.pieces, id: \.url) { piece in
                VignettePieceDistante(piece: piece)
            }
        }
    }
}

/// Un tour de l'orchestrateur : ses blocs pleine largeur, puis l'attribution
/// en pied — modèle, effort, heure de fin.
private struct VueTourAgent: View {
    let tour: TourAgent

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            ForEach(tour.blocs) { bloc in
                VueBlocAgent(bloc: bloc)
            }
            pied
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `☠` L'attribution est PAR TOUR, jamais le dernier réglage en date :
    /// relire un fil où l'on a changé de modèle doit montrer ce qui a
    /// réellement produit chaque réponse.
    private var pied: some View {
        HStack(spacing: Trame.fin) {
            if let modele = tour.modele {
                Text(Lisible.moteur(modele: modele, effort: tour.effort))
            }
            Text("— \(heureFil(tour.finA))")
        }
        .donneeMinuscule()
        .foregroundStyle(Teinte.encreTernie)
    }
}

/// Le fil compacté — un fait d'administration : filet et ligne centrée,
/// jamais une bulle, ce n'est ni Chris ni l'agent qui parle.
private struct VueCompaction: View {
    let resume: String
    let at: Int

    var body: some View {
        VStack(spacing: Trame.fin) {
            HStack(spacing: Trame.serre) {
                FiletFin()
                Text("fil compacté · \(heureFil(at))")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
                    .fixedSize()
                FiletFin()
            }
            if !resume.isEmpty {
                Text(resume)
                    .note()
                    .foregroundStyle(Teinte.encreDouce)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
#endif
