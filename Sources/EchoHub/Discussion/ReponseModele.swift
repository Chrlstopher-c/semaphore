// Ce que le modèle répond, et tout ce qu'il a écrit avant d'y arriver.
//
// C'est l'écran du produit. Le découpage lui-même vit dans le noyau
// (`SegmenteurReponse`, testé) ; cette vue ne fait que le peindre selon le
// registre — voir `CHARTE.md`, § Le registre.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct ReponseModele: View {
    /// Le texte BRUT tel que le modèle l'a écrit, balises comprises.
    let texte: String
    /// La génération est-elle en cours ? Le texte seul ne peut pas le savoir, et
    /// la différence est visible : un bloc jamais refermé est « en train de
    /// s'écrire » pendant une génération, « coupé net » après.
    let actif: Bool
    /// L'identifiant du message, pour la mémoire des analyses : hacher 500 Ko de texte à chaque rendu chauffait.
    var cle: String?
    /// Combien d'étapes (raisonnements, appels d'outil) se montrent, depuis la fin.
    /// `☠` Un tour d'agent en compte des centaines : toutes peintes d'un coup, l'app tombait et le téléphone chauffait.
    @State private var etapes = Self.pasEtapes
    private static let pasEtapes = 8

    var body: some View {
        let segmentee = segmenter()
        let muette = tourMuet(segmentee)
        let masquees = segmentee.raisonnements.count - etapes
        VStack(alignment: .leading, spacing: Trame.element) {
            if masquees > 0 {
                Button("\(masquees) étapes précédentes") { etapes += 20 }
                    .buttonStyle(.appui).legende().foregroundStyle(Teinte.accent)
            }
            ForEach(segmentee.raisonnements.suffix(etapes)) { segment in
                BlocReplie(
                    segment: segment, actif: actif,
                    ouvertParDefaut: muette && segment.id == segmentee.raisonnements.last?.id
                )
            }
            reponse(segmentee.visible)
            if actif && segmentee.visible.isEmpty {
                CurseurGeneration()
            }
            if !actif && visibleVide(segmentee) {
                epilogueVide(segmentee)
            }
        }
    }

    private func segmenter() -> ReponseSegmentee {
        if actif { return SegmenteurReponse.segmenter(texte) }
        if let cle { return SegmenteurReponse.segmenterMemorise(texte, cle: cle) }
        return SegmenteurReponse.segmenterMemorise(texte)
    }

    /// La réponse : le SEUL texte de l'app composé en encre pleine à 17 pt,
    /// avec l'interligne de lecture — c'est ce qui en fait le sujet de l'écran.
    ///
    /// Le découpage en blocs vit dans le noyau (`AnalyseMarkdown`, porté du
    /// frontend avec sa batterie) ; cette vue ne fait que le peindre.
    @ViewBuilder private func reponse(_ visible: String) -> some View {
        let propre = visible.trimmingCharacters(in: .whitespacesAndNewlines)
        if !propre.isEmpty {
            RenduMarkdown(source: propre, memoriser: !actif)
        }
    }

    // MARK: - Le tour sans réponse adressée

    /// Un modèle de raisonnement peut dépenser tout son tour en `<think>` : la
    /// part adressée est alors VIDE, et un tour qui ne montre qu'un bloc replié
    /// ressemble à un bug d'affichage. L'épilogue nomme ce qui s'est passé, et
    /// le dernier bloc s'ouvre de lui-même — c'est la seule chose à lire.
    private func tourMuet(_ segmentee: ReponseSegmentee) -> Bool {
        !actif && visibleVide(segmentee) && !segmentee.raisonnements.isEmpty
    }

    private func visibleVide(_ segmentee: ReponseSegmentee) -> Bool {
        segmentee.visible.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder private func epilogueVide(_ segmentee: ReponseSegmentee) -> some View {
        Text(segmentee.raisonnements.isEmpty
            ? "Rien n'est arrivé avant l'interruption."
            : "Rien d'adressé : toute la réponse est restée en raisonnement.")
            .note()
            .foregroundStyle(Teinte.encreDouce)
    }
}

/// Le battement qui dit « ça génère ».
///
/// `☠` Il ne simule rien — règle héritée du refus explicite d'EchoHub v2 au
/// bureau : la progression affichée est la progression réelle. Ce curseur
/// n'apparaît que tant qu'aucun texte visible n'est encore arrivé, et disparaît
/// au premier caractère. Il ne prétend pas connaître une durée.
struct CurseurGeneration: View {
    @State private var bat = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Teinte.accent)
            .frame(width: 2, height: 18)
            .opacity(bat ? 0.25 : 1)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: bat)
            .onAppear { bat = true }
            .accessibilityLabel("Génération en cours")
    }
}
#endif
