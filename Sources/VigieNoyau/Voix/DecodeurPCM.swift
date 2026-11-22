import Foundation

// Responsabilité : décoder le flux PCM de la voix de la tour (s16le mono 24 kHz) en échantillons flottants, morceau
// par morceau — un morceau du réseau peut couper un échantillon en deux, l'octet isolé attend le suivant. Pur, testé
// sous Linux.

public struct DecodeurPCM: Sendable {
    private var reste: [UInt8] = []

    public init() {}

    /// Les échantillons complets, en -1…1, de `octets` précédé de ce qui attendait.
    public mutating func ajouter(_ octets: Data) -> [Float] {
        var brut = reste
        brut.append(contentsOf: octets)
        let complets = brut.count / 2 * 2
        reste = Array(brut[complets...])
        return stride(from: 0, to: complets, by: 2).map { i in
            let valeur = Int16(bitPattern: UInt16(brut[i]) | (UInt16(brut[i + 1]) << 8))
            return Float(valeur) / 32768
        }
    }

    /// Octets restés sans échantillon complet (0 ou 1).
    public var enAttente: Int { reste.count }
}
