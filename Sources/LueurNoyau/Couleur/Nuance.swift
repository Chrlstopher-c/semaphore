// Une couleur du ruban : trois octets, sa forme hexadécimale (celle du serveur) et sa place sur la roue.
import Foundation

public struct Nuance: Hashable, Sendable {
    public let rouge: UInt8
    public let vert: UInt8
    public let bleu: UInt8

    public init(rouge: UInt8, vert: UInt8, bleu: UInt8) {
        self.rouge = rouge
        self.vert = vert
        self.bleu = bleu
    }

    /// `#rrggbb`, casse indifférente ; `nil` pour toute autre forme.
    public init?(hexa: String) {
        let chiffres = hexa.hasPrefix("#") ? hexa.dropFirst() : Substring(hexa)
        guard chiffres.count == 6, let valeur = UInt32(chiffres, radix: 16) else { return nil }
        self.init(rouge: UInt8(valeur >> 16 & 0xFF), vert: UInt8(valeur >> 8 & 0xFF), bleu: UInt8(valeur & 0xFF))
    }

    public var hexa: String {
        String(format: "#%02x%02x%02x", rouge, vert, bleu)
    }

    /// Luminosité pleine (v = 1) : l'intensité du ruban se règle à part, pas sur la roue.
    /// `teinte` en degrés [0, 360), `saturation` dans [0, 1].
    public init(teinte: Double, saturation: Double) {
        let s = min(max(saturation, 0), 1)
        let h = (teinte.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        func canal(_ n: Double) -> UInt8 {
            let k = (n + h / 60).truncatingRemainder(dividingBy: 6)
            return UInt8((255 * (1 - s * max(0, min(k, 4 - k, 1)))).rounded())
        }
        self.init(rouge: canal(5), vert: canal(3), bleu: canal(1))
    }

    /// Place sur la roue (teinte en degrés, saturation) ; la valeur est ignorée, la roue n'en a pas.
    public var placeSurRoue: (teinte: Double, saturation: Double) {
        let r = Double(rouge) / 255, v = Double(vert) / 255, b = Double(bleu) / 255
        let maxi = max(r, v, b)
        let ecart = maxi - min(r, v, b)
        guard ecart > 0 else { return (0, 0) }
        let secteur: Double
        switch maxi {
        case r: secteur = ((v - b) / ecart).truncatingRemainder(dividingBy: 6)
        case v: secteur = (b - r) / ecart + 2
        default: secteur = (r - v) / ecart + 4
        }
        return ((secteur * 60 + 360).truncatingRemainder(dividingBy: 360), ecart / maxi)
    }
}
