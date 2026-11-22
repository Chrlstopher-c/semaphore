import Foundation

// Responsabilité : la file de préparation du mode vocal — chaque morceau de la réponse est préparé (synthèse, décodage)
// dès son arrivée, au plus `enVol` à la fois, et rendu dans l'ordre d'arrivée même si les préparations répondent dans
// le désordre. Aucun son ici : le lecteur joue ce qui sort. Pur, testé sous Linux.

public struct MorceauPrepare<Audio: Sendable>: Sendable {
    public let texte: String
    public let audio: Task<Audio?, Never>
}

public final class FileVocale<Audio: Sendable> {
    public typealias Preparation = @Sendable (String) async -> Audio?

    private let enVol: Int
    private var attente: [MorceauPrepare<Audio>] = []
    /// Les `enVol` dernières préparations : une nouvelle attend la plus ancienne de cette fenêtre.
    private var fenetre: [Task<Audio?, Never>] = []
    /// Toutes les préparations du tour en cours, pour les annuler d'un coup (passer, coupure).
    private var toutes: [Task<Audio?, Never>] = []

    public init(enVol: Int) {
        self.enVol = max(1, enVol)
    }

    public var vide: Bool { attente.isEmpty }

    public func ajouter(_ texte: String, preparer: @escaping Preparation) {
        let precedente = fenetre.count >= enVol ? fenetre.removeFirst() : nil
        let tache = Task { () -> Audio? in
            _ = await precedente?.value
            return await preparer(texte)
        }
        fenetre.append(tache)
        toutes.append(tache)
        attente.append(MorceauPrepare(texte: texte, audio: tache))
    }

    /// Le morceau suivant dans l'ordre d'arrivée, ou nil quand il n'y en a plus (le tour est alors terminé).
    public func prochain() -> MorceauPrepare<Audio>? {
        guard !attente.isEmpty else {
            fenetre = []
            toutes = []
            return nil
        }
        return attente.removeFirst()
    }

    /// Coupe les préparations en cours et vide la file.
    public func annuler() {
        for tache in toutes { tache.cancel() }
        attente = []
        fenetre = []
        toutes = []
    }
}
