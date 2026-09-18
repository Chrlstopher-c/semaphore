import Foundation

/// L'en-tête de douze octets qui précède chaque paquet audio, tel que
/// `PROTOCOLE.md` le fige. Pur : aucune dépendance réseau, donc éprouvé par
/// `swift test` sur Linux — sans simulateur, c'est la seule preuve automatique
/// que l'app lit bien ce que le PC écrit.
///
/// `☠` Les deux entiers sont en GROS-BOUTISTE (ordre réseau), alors que la
/// charge PCM qui suit est en PETIT-BOUTISTE. Les deux conventions cohabitent
/// dans le même paquet : c'est contre-intuitif, c'est le contrat, et l'inverser
/// ne casse pas la lecture — ça la décale silencieusement.
public struct EnTetePaquet: Sendable, Equatable {

    // MARK: - Les constantes du format, jamais négociées

    /// « DX » — les deux premiers octets. Un paquet qui ne les porte pas n'est
    /// pas à nous : le port UDP est ouvert, n'importe qui peut y écrire.
    public static let marqueur: (UInt8, UInt8) = (0x44, 0x58)
    public static let version: UInt8 = 1
    /// Taille de l'en-tête.
    public static let taille = 12
    /// 240 trames stéréo = 5 ms à 48 kHz.
    public static let tramesParPaquet = 240
    public static let canaux = 2
    public static let frequence: Double = 48_000
    /// 240 trames × 2 canaux × 2 octets.
    public static let octetsCharge = tramesParPaquet * canaux * MemoryLayout<Int16>.size
    /// 972 octets — sous la MTU, jamais fragmenté.
    public static let taillePaquet = taille + octetsCharge

    // MARK: - Ce que porte l'en-tête

    /// +1 par paquet, en gros-boutiste. Reboucle après ~248 jours d'écoute
    /// continue ; `SuiviFlux` encaisse le rebouclage.
    public let sequence: UInt32
    /// Compteur d'échantillons à 48 kHz, en gros-boutiste.
    public let horodatage: UInt32
    /// Bit 0 = 0 : PCM brut. Les autres bits sont réservés à 0.
    public let drapeaux: UInt8

    public init(sequence: UInt32, horodatage: UInt32, drapeaux: UInt8 = 0) {
        self.sequence = sequence
        self.horodatage = horodatage
        self.drapeaux = drapeaux
    }

    /// Le bit 0 réserve la place d'Opus. Tant qu'il vaut 0, la charge est du PCM
    /// brut — et cette version d'app ne sait lire que celui-là.
    public var pcmBrut: Bool { drapeaux & 0x01 == 0 }
}

/// Ce qu'une lecture de paquet peut donner. Un rejet n'est jamais fatal : on
/// jette le datagramme et on attend le suivant.
public enum LecturePaquet: Sendable, Equatable {
    case valide(EnTetePaquet)
    case rejete(MotifRejet)
}

/// Pourquoi un datagramme n'est pas un paquet Duplex lisible. Chaque motif est
/// distinct parce qu'ils ne se réparent pas pareil : un marqueur inconnu est un
/// voisin bavard, une version inconnue est un PC plus récent que l'app.
public enum MotifRejet: Sendable, Equatable {
    case tropCourt(octets: Int)
    case marqueurInconnu
    case versionInconnue(UInt8)
    /// Un drapeau posé que cette version ne sait pas honorer — Opus, demain.
    case codageNonSupporte(drapeaux: UInt8)
    case chargeIncomplete(octets: Int)
}

extension EnTetePaquet {

    /// Lit l'en-tête d'un datagramme et valide sa charge. Ne copie rien : rend
    /// l'en-tête, l'appelant tranche la charge lui-même s'il la veut.
    public static func analyser(_ donnees: Data) -> LecturePaquet {
        guard donnees.count >= taille else { return .rejete(.tropCourt(octets: donnees.count)) }
        let octets = [UInt8](donnees.prefix(taille))
        guard octets[0] == marqueur.0, octets[1] == marqueur.1 else {
            return .rejete(.marqueurInconnu)
        }
        guard octets[2] == version else { return .rejete(.versionInconnue(octets[2])) }
        let drapeaux = octets[3]
        guard drapeaux & 0x01 == 0 else { return .rejete(.codageNonSupporte(drapeaux: drapeaux)) }
        let charge = donnees.count - taille
        guard charge == octetsCharge else { return .rejete(.chargeIncomplete(octets: charge)) }
        return .valide(EnTetePaquet(
            sequence: grosBoutiste(octets, a: 4),
            horodatage: grosBoutiste(octets, a: 8),
            drapeaux: drapeaux
        ))
    }

    /// La charge PCM d'un datagramme déjà validé, décodée en échantillons
    /// entrelacés gauche/droite.
    ///
    /// `☠` Petit-boutiste, alors que l'en-tête est en gros-boutiste. Le décalage
    /// d'un octet ne produit pas une erreur : il produit du bruit blanc.
    public static func echantillons(_ donnees: Data) -> [Int16] {
        let charge = donnees.dropFirst(taille)
        var sortie = [Int16](repeating: 0, count: charge.count / 2)
        let octets = [UInt8](charge)
        for index in 0..<sortie.count {
            let bas = UInt16(octets[index * 2])
            let haut = UInt16(octets[index * 2 + 1]) << 8
            sortie[index] = Int16(bitPattern: haut | bas)
        }
        return sortie
    }

    private static func grosBoutiste(_ octets: [UInt8], a debut: Int) -> UInt32 {
        (UInt32(octets[debut]) << 24) | (UInt32(octets[debut + 1]) << 16)
            | (UInt32(octets[debut + 2]) << 8) | UInt32(octets[debut + 3])
    }

    /// Compose un paquet complet. Le PC est le seul émetteur réel ; ceci est le
    /// MIROIR de son encodage, et il sert à éprouver l'analyse sous `swift test`.
    /// Interne à dessein : l'app ne diffuse jamais d'audio.
    static func composer(_ entete: EnTetePaquet, charge: [Int16]) -> Data {
        var donnees = Data(capacity: taillePaquet)
        donnees.append(contentsOf: [marqueur.0, marqueur.1, version, entete.drapeaux])
        donnees.append(contentsOf: grosBoutistes(entete.sequence))
        donnees.append(contentsOf: grosBoutistes(entete.horodatage))
        for echantillon in charge {
            let brut = UInt16(bitPattern: echantillon)
            donnees.append(UInt8(brut & 0xFF))
            donnees.append(UInt8(brut >> 8))
        }
        return donnees
    }

    private static func grosBoutistes(_ valeur: UInt32) -> [UInt8] {
        [
            UInt8((valeur >> 24) & 0xFF), UInt8((valeur >> 16) & 0xFF),
            UInt8((valeur >> 8) & 0xFF), UInt8(valeur & 0xFF),
        ]
    }
}
