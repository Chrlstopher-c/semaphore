import Foundation

/// Ce que devient un paquet reçu, une fois sa séquence comparée à la précédente.
public enum VerdictSequence: Sendable, Equatable {
    /// Le tout premier paquet du flux : rien à comparer.
    case premier
    /// La suite attendue.
    case continu
    /// Un saut : il manque exactement ce nombre de trames, à combler en silence.
    case trou(tramesManquantes: Int)
    /// Un saut trop grand pour être comblé — le PC a coupé, ou on a perdu le
    /// réseau plusieurs secondes. On ne fabrique pas des minutes de silence :
    /// on jette le tampon et on réamorce.
    case rupture(paquetsManquants: Int)
    /// Séquence déjà vue, ou arrivée après sa suivante. UDP ne garantit pas
    /// l'ordre ; on jette plutôt que de réordonner — la latence prime.
    case doublonOuRetard
}

/// Le suivi de séquence du flux audio : détection de trou, de rupture et de
/// doublon, plus le compte de ce qui s'est passé pour l'afficher à Chris.
///
/// Pur et sans horloge : c'est ce qui le rend éprouvable sous `swift test`.
///
/// `☠` La séquence est un `UInt32` qui REBOUCLE (~248 jours à 200 paquets/s).
/// L'écart se calcule donc par soustraction cyclique (`&-`), jamais par un
/// `>` : à l'instant du rebouclage, une comparaison ordinaire verrait un saut
/// de quatre milliards et jetterait tout le flux.
public struct SuiviFlux: Sendable, Equatable {

    /// Au-delà, on ne comble plus : on réamorce. Deux secondes — 400 paquets.
    /// Combler plus long remplirait le tampon de silence et ferait grimper la
    /// latence d'autant, sans jamais la redescendre.
    public static let plafondTrouPaquets = 400

    /// Un écart supérieur à la moitié de l'espace des séquences se lit comme un
    /// paquet en RETARD, pas comme un saut en avant de deux milliards.
    private static let moitie = UInt32(1) << 31

    public private(set) var derniereSequence: UInt32?
    public private(set) var paquetsRecus = 0
    public private(set) var paquetsPerdus = 0
    public private(set) var trous = 0
    public private(set) var ruptures = 0
    public private(set) var doublons = 0

    public init() {}

    /// Combien de trames manquent, en tout, depuis le début de l'écoute.
    public var tramesPerdues: Int { paquetsPerdus * EnTetePaquet.tramesParPaquet }

    /// Accueille une séquence et dit ce qu'il faut en faire. Met à jour les
    /// compteurs au passage — un doublon ne fait jamais reculer la référence.
    public mutating func accueillir(sequence: UInt32) -> VerdictSequence {
        guard let derniere = derniereSequence else {
            derniereSequence = sequence
            paquetsRecus += 1
            return .premier
        }
        let ecart = sequence &- derniere
        if ecart == 0 || ecart >= Self.moitie {
            doublons += 1
            return .doublonOuRetard
        }
        derniereSequence = sequence
        paquetsRecus += 1
        if ecart == 1 { return .continu }
        let manquants = Int(ecart) - 1
        paquetsPerdus += manquants
        if manquants > Self.plafondTrouPaquets {
            ruptures += 1
            return .rupture(paquetsManquants: manquants)
        }
        trous += 1
        return .trou(tramesManquantes: manquants * EnTetePaquet.tramesParPaquet)
    }

    /// Oublie la référence de séquence : après une rupture ou un arrêt, le
    /// prochain paquet repart en `.premier` au lieu d'inventer un trou géant.
    public mutating func reprendre() {
        derniereSequence = nil
    }
}
