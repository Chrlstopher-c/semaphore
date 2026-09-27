// La photothèque en couches : une strate par année, une sous-strate par mois.
// C'est la vue qui répond à la seule question qui compte pour libérer iCloud —
// où est le poids ?
import Foundation

public struct Couche: Sendable, Hashable, Identifiable {
    public let annee: Int
    /// Nul pour la strate annuelle.
    public let mois: Int?
    public let nombre: Int
    public let poids: Int64
    /// Ce qui, dans cette couche, est déjà au panier.
    public let poidsPanier: Int64

    public var id: String { mois.map { "\(annee)-\($0)" } ?? "\(annee)" }
}

public struct Strate: Sendable, Hashable, Identifiable {
    public let annee: Couche
    public let mois: [Couche]
    public var id: Int { annee.annee }
}

public enum Stratigraphie {
    /// Les strates de la plus récente à la plus ancienne ; les clichés sans
    /// date sont écartés et comptés à part par l'appelant.
    public static func calculer(
        _ cliches: [Cliche], panier: Set<String>, calendrier: Calendar = .current
    ) -> [Strate] {
        var parMois: [Int: [Int: [Cliche]]] = [:]
        for cliche in cliches {
            guard let date = cliche.date else { continue }
            let c = calendrier.dateComponents([.year, .month], from: date)
            guard let annee = c.year, let mois = c.month else { continue }
            parMois[annee, default: [:]][mois, default: []].append(cliche)
        }
        return parMois.keys.sorted(by: >).map { annee in
            let mois = parMois[annee] ?? [:]
            let couches = mois.keys.sorted(by: >).map { m in
                couche(annee: annee, mois: m, mois[m] ?? [], panier: panier)
            }
            return Strate(annee: somme(annee: annee, couches), mois: couches)
        }
    }

    private static func couche(annee: Int, mois: Int?, _ cliches: [Cliche], panier: Set<String>) -> Couche {
        let auPanier = cliches.filter { panier.contains($0.id) }
        return Couche(
            annee: annee, mois: mois, nombre: cliches.count,
            poids: cliches.poidsTotal, poidsPanier: auPanier.poidsTotal
        )
    }

    private static func somme(annee: Int, _ couches: [Couche]) -> Couche {
        Couche(
            annee: annee, mois: nil,
            nombre: couches.reduce(0) { $0 + $1.nombre },
            poids: couches.reduce(0) { $0 + $1.poids },
            poidsPanier: couches.reduce(0) { $0 + $1.poidsPanier }
        )
    }
}
