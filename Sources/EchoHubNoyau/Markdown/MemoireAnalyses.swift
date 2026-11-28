import Foundation

/// Les analyses de texte déjà faites, gardées pour le prochain rendu.
///
/// `☠` Sans elle, chaque message d'une longue session refaisait sa segmentation et son Markdown à CHAQUE rendu du
/// fil (un fragment reçu, un défilement) : des centaines d'analyses par seconde, le fil saccadait.
/// Un texte en cours d'écriture ne passe pas par ici : il change à chaque fragment et viderait la mémoire.
final class MemoireAnalyses<Valeur>: @unchecked Sendable {
    private var valeurs: [String: Valeur] = [:]
    private let verrou = NSLock()
    private let capacite: Int

    init(capacite: Int = 400) { self.capacite = capacite }

    func valeur(_ cle: String, calcul: () -> Valeur) -> Valeur {
        verrou.lock()
        if let connue = valeurs[cle] {
            verrou.unlock()
            return connue
        }
        verrou.unlock()
        let calculee = calcul()
        verrou.lock()
        if valeurs.count >= capacite { valeurs.removeAll(keepingCapacity: true) }
        valeurs[cle] = calculee
        verrou.unlock()
        return calculee
    }
}

extension SegmenteurReponse {
    private static let memoire = MemoireAnalyses<ReponseSegmentee>()

    /// Pour un texte figé (message terminé) : calculé une fois.
    public static func segmenterMemorise(_ source: String) -> ReponseSegmentee {
        memoire.valeur(source) { segmenter(source) }
    }
}

extension AnalyseMarkdown {
    private static let memoire = MemoireAnalyses<[BlocIndexe]>()

    public static func analyserMemorise(_ source: String) -> [BlocIndexe] {
        memoire.valeur(source) { analyser(source) }
    }
}
