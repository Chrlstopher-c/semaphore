// Le comparateur à fenêtre glissante. Les photos semblables se prennent presque
// toujours à quelques minutes d'écart (reprises, rafales manuelles, envois
// doublés) : comparer chaque photo aux seules voisines dans le temps rend
// l'analyse linéaire au lieu de quadratique — 35 000 photos, pas 600 millions de
// paires.
import Foundation

public struct Regroupeur: Sendable {
    /// Écart maximal entre deux photos comparées.
    public let fenetre: TimeInterval
    /// Similarité sous laquelle une paire n'est même pas notée. Plus bas que
    /// tout seuil proposé à l'écran, pour pouvoir le régler après coup sans
    /// relancer l'analyse.
    public let plancher: Float
    /// Nombre de voisines retenues au plus, pour borner le coût d'une rafale.
    public let profondeur: Int
    private var recentes: [Empreinte] = []

    public init(fenetre: TimeInterval = 900, plancher: Float = 0.80, profondeur: Int = 32) {
        self.fenetre = fenetre
        self.plancher = plancher
        self.profondeur = profondeur
    }

    /// `empreinte` doit arriver dans l'ordre chronologique. Rend les paires
    /// qu'elle forme avec ses voisines.
    public mutating func ajouter(_ empreinte: Empreinte) -> [Paire] {
        recentes.removeAll { empreinte.date.timeIntervalSince($0.date) > fenetre }
        let paires = recentes.compactMap { voisine -> Paire? in
            let s = empreinte.similarite(voisine)
            return s >= plancher ? Paire(a: voisine.id, b: empreinte.id, similarite: s) : nil
        }
        recentes.append(empreinte)
        if recentes.count > profondeur { recentes.removeFirst(recentes.count - profondeur) }
        return paires
    }
}
