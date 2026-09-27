// Des paires aux groupes : union-find sur les paires au-dessus du seuil choisi.
// Les doublons exacts, eux, se reconnaissent sans Vision.
import Foundation

public enum Grappes {
    /// Les groupes d'au moins deux photos, triés par taille décroissante.
    public static func former(_ paires: [Paire], seuil: Float) -> [[String]] {
        var parent: [String: String] = [:]
        func racine(_ x: String) -> String {
            var r = x
            while let p = parent[r], p != r { r = p }
            var y = x
            while let p = parent[y], p != r { parent[y] = r; y = p }
            return r
        }
        for paire in paires where paire.similarite >= seuil {
            if parent[paire.a] == nil { parent[paire.a] = paire.a }
            if parent[paire.b] == nil { parent[paire.b] = paire.b }
            let ra = racine(paire.a), rb = racine(paire.b)
            if ra != rb { parent[max(ra, rb)] = min(ra, rb) }
        }
        var groupes: [String: [String]] = [:]
        for id in parent.keys { groupes[racine(id), default: []].append(id) }
        return groupes.values
            .filter { $0.count > 1 }
            .map { $0.sorted() }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0[0] < $1[0] }
    }

    /// Mêmes dimensions, même instant à la seconde, même poids : le même fichier
    /// importé deux fois. Les poids inconnus ne concluent jamais.
    public static func doublonsExacts(_ cliches: [Cliche]) -> [[String]] {
        var parCle: [String: [String]] = [:]
        for c in cliches {
            guard let date = c.date, let poids = c.poids else { continue }
            let cle = "\(c.media.rawValue)|\(Int(date.timeIntervalSince1970))|\(c.largeur)x\(c.hauteur)|\(poids)"
            parCle[cle, default: []].append(c.id)
        }
        return parCle.values.filter { $0.count > 1 }.map { $0.sorted() }.sorted { $0[0] < $1[0] }
    }
}
