// Le calcul de toutes les pistes à partir de l'inventaire et du carnet d'analyse.
import Foundation

public struct Pistage: Sendable {
    public let cliches: [String: Cliche]
    public let qualites: [String: Qualite]
    public let paires: [Paire]
    /// Ce que Chris a explicitement gardé : aucune piste ne le repropose.
    public let gardes: Set<String>
    public let reglage: ReglagePistes

    public init(
        cliches: [Cliche], qualites: [String: Qualite], paires: [Paire],
        gardes: Set<String>, reglage: ReglagePistes = ReglagePistes()
    ) {
        self.cliches = Dictionary(cliches.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.qualites = qualites
        self.paires = paires
        self.gardes = gardes
        self.reglage = reglage
    }

    public func releves() -> [Releve] {
        Piste.allCases.map(releve).filter { !$0.proposes.isEmpty }
    }

    public func releve(_ piste: Piste) -> Releve {
        if piste.parGroupes {
            let groupes = groupes(piste)
            let proposes = groupes.flatMap {
                Election.surplus($0, cliches: cliches, qualites: qualites, gardes: gardes)
            }
            return fabriquer(piste, groupes: groupes, proposes)
        }
        return fabriquer(piste, groupes: [], cliches.values.filter { propose(piste, $0) }.map(\.id))
    }

    private func groupes(_ piste: Piste) -> [[String]] {
        switch piste {
        case .doublons:
            return Grappes.doublonsExacts(Array(cliches.values))
        case .similaires:
            let valides = paires.filter { cliches[$0.a] != nil && cliches[$0.b] != nil }
            return Grappes.former(valides, seuil: reglage.seuilSimilarite)
        case .rafales:
            let parRafale = Dictionary(grouping: cliches.values.filter { $0.rafale != nil }) { $0.rafale ?? "" }
            return parRafale.values.filter { $0.count > 1 }.map { $0.map(\.id).sorted() }
        default:
            return []
        }
    }

    private func propose(_ piste: Piste, _ c: Cliche) -> Bool {
        guard !gardes.contains(c.id), !c.estFavori else { return false }
        switch piste {
        case .captures:
            return c.traits.contains(.capture)
        case .utilitaires:
            return c.media == .photo && !c.traits.contains(.capture) && qualites[c.id]?.utilitaire == true
        case .ratees:
            guard let q = qualites[c.id], !q.utilitaire, c.media == .photo else { return false }
            return q.score < reglage.scoreRatee
        case .videosLourdes:
            return c.media == .video && (c.poids ?? 0) >= reglage.videoLourde
        case .videosFurtives:
            return c.media == .video && c.duree > 0 && c.duree < reglage.videoFurtive
        default:
            return false
        }
    }

    private func fabriquer(_ piste: Piste, groupes: [[String]], _ ids: [String]) -> Releve {
        let retenus = Array(Set(ids)).compactMap { cliches[$0] }.sorted(by: Tamisage.chronologique)
        return Releve(piste: piste, groupes: groupes, proposes: retenus.map(\.id), poids: retenus.poidsTotal)
    }
}
