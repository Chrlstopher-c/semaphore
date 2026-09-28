import Foundation

/// VideoToolbox rend du H.264 au format AVCC (chaque NAL précédée de sa
/// longueur) ; le décodeur du PC lit un flux Annex-B (chaque NAL précédée de
/// `00 00 00 01`). Pur, donc éprouvé sur Linux.
///
/// `☠` Les jeux de paramètres (SPS, PPS) ne sont PAS dans l'échantillon : ils
/// vivent dans la description de format. Une image clé envoyée sans eux est
/// indécodable — un PC qui rejoint en cours de route attendrait pour rien.
public enum AnnexeB {
    public static let prefixe = Data([0, 0, 0, 1])

    /// Convertit un bloc AVCC. `nil` si une longueur déborde : bloc corrompu,
    /// mieux vaut sauter l'image que l'envoyer tronquée.
    public static func depuisAVCC(_ avcc: Data, tailleLongueur: Int = 4) -> Data? {
        let octets = [UInt8](avcc)
        var sortie = Data(capacity: octets.count + 16)
        var curseur = 0
        while curseur < octets.count {
            guard curseur + tailleLongueur <= octets.count else { return nil }
            var longueur = 0
            for rang in 0..<tailleLongueur { longueur = longueur << 8 | Int(octets[curseur + rang]) }
            curseur += tailleLongueur
            guard longueur > 0, curseur + longueur <= octets.count else { return nil }
            sortie.append(prefixe)
            sortie.append(contentsOf: octets[curseur..<curseur + longueur])
            curseur += longueur
        }
        return sortie
    }

    /// L'unité d'accès complète : jeux de paramètres en tête sur une image clé.
    public static func uniteAcces(parametres: [Data], avcc: Data, tailleLongueur: Int = 4) -> Data? {
        guard let corps = depuisAVCC(avcc, tailleLongueur: tailleLongueur) else { return nil }
        var unite = Data()
        for jeu in parametres {
            unite.append(prefixe)
            unite.append(jeu)
        }
        unite.append(corps)
        return unite
    }

    /// Trame posée sur la liaison TCP : longueur sur 4 octets gros-boutistes, puis l'unité.
    public static func encadrer(_ unite: Data) -> Data {
        let n = UInt32(unite.count)
        var trame = Data([UInt8(n >> 24 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n & 0xFF)])
        trame.append(unite)
        return trame
    }
}
