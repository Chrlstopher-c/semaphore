import Foundation

/// La lecture à débit variable : c'est elle qui applique concrètement le facteur
/// calculé par `CorrectionDerive`. Pour produire une trame de sortie, elle
/// avance d'un peu plus (ou d'un peu moins) qu'une trame dans la source et
/// interpole entre les deux trames voisines.
///
/// Interpolation LINÉAIRE, et c'est assumé : à ±0,3 % le rééchantillonnage est
/// si doux que la distorsion introduite reste largement sous le plancher de
/// bruit. Un polyphase coûterait du CPU dans le rendu temps réel pour une
/// différence inaudible.
///
/// `☠` La phase appartient au LECTEUR seul, jamais au producteur. C'est ce qui
/// laisse cette structure vivre dans le rappel de rendu sans verrou : personne
/// d'autre ne la touche.
public struct LectureEtiree: Sendable, Equatable {

    /// Où l'on se trouve dans la trame de tête, entre 0 et 1.
    public private(set) var phase: Double = 0

    public init() {}

    /// Combien de trames sources il faut avoir sous la main pour produire
    /// `trames` trames de sortie à ce facteur — la trame suivante comprise,
    /// puisque l'interpolation a besoin du voisin de droite.
    public func besoinEnTrames(_ trames: Int, facteur: Double) -> Int {
        guard trames > 0 else { return 0 }
        return Int((phase + facteur * Double(trames)).rounded(.up)) + 1
    }

    /// Produit `trames` trames stéréo. `source` rend la trame à un décalage
    /// donné depuis la tête de lecture ; `sortie` reçoit chaque trame produite.
    /// Rend le nombre de trames SOURCES consommées, à retrancher du tampon.
    ///
    /// Les deux fermetures sont non-échappantes : rien n'est alloué ici, ce qui
    /// est la condition pour tourner dans un rappel de rendu audio.
    public mutating func produire(
        trames: Int,
        facteur: Double,
        source: (Int) -> (Int16, Int16),
        sortie: (Int, Int16, Int16) -> Void
    ) -> Int {
        for index in 0..<trames {
            let entier = Int(phase)
            let fraction = phase - Double(entier)
            let gauche = source(entier)
            let droite = source(entier + 1)
            sortie(
                index,
                Self.meler(gauche.0, droite.0, fraction),
                Self.meler(gauche.1, droite.1, fraction)
            )
            phase += facteur
        }
        let consommees = Int(phase)
        phase -= Double(consommees)
        return consommees
    }

    /// Repart de zéro. Après un réamorçage, la phase d'avant ne veut plus rien
    /// dire — la tête de lecture a bougé d'un bloc entier.
    public mutating func reinitialiser() {
        phase = 0
    }

    /// Interpolation linéaire entre deux échantillons, bornée à la plage 16 bits
    /// pour qu'un arrondi ne fasse jamais reboucler un maximum en minimum — ce
    /// qui s'entendrait comme un claquement.
    static func meler(_ gauche: Int16, _ droite: Int16, _ part: Double) -> Int16 {
        let valeur = Double(gauche) + (Double(droite) - Double(gauche)) * part
        let bornee = min(max(valeur.rounded(), Double(Int16.min)), Double(Int16.max))
        return Int16(bornee)
    }
}
