import Foundation

/// Une grandeur qui ne se lit pas, qui se **calcule sur l'écart entre deux
/// relevés** : la charge processeur et les débits réseau.
///
/// `☠` Elles valent `nil` au PREMIER passage après le démarrage de la machine —
/// `metriques-hote.ts` compare le relevé courant au précédent, et il n'y en a
/// pas encore. Ce n'est pas une sonde cassée, et l'afficher comme une absence
/// (« — », au même titre qu'un capteur thermique manquant sur un VPS) enverrait
/// chercher une panne là où il n'y a qu'une seconde à attendre.
public enum MesureDifferentielle<Grandeur: Sendable & Equatable>: Sendable, Equatable {
    /// L'écart a pu être calculé.
    case mesuree(Grandeur)
    /// Un seul relevé connu à ce jour : la mesure arrive au prochain.
    case enCoursDeMesure

    public init(_ brute: Grandeur?) {
        self = brute.map(MesureDifferentielle.mesuree) ?? .enCoursDeMesure
    }

    public var valeur: Grandeur? {
        if case .mesuree(let grandeur) = self { return grandeur }
        return nil
    }

    public var enAttente: Bool { self == .enCoursDeMesure }
}

extension MetriquesHote {
    /// Charge processeur, en distinguant « pas encore calculable » de « absente ».
    public var chargeProcesseur: MesureDifferentielle<Int> {
        MesureDifferentielle(cpuPct)
    }

    /// Débit sortant, en kilo-octets par seconde.
    public var debitMontant: MesureDifferentielle<Double> {
        MesureDifferentielle(reseauMontantKo)
    }

    public var debitDescendant: MesureDifferentielle<Double> {
        MesureDifferentielle(reseauDescendantKo)
    }

    /// Part du disque occupée, 0…1. `nil` quand la taille du volume est inconnue :
    /// une barre sans dénominateur ne veut rien dire.
    public var partDisque: Double? {
        guard let total = disqueTotalGo, total > 0, let utilise = disqueUtiliseGo else { return nil }
        return min(max(utilise / total, 0), 1)
    }

    /// Part de mémoire occupée, 0…1, à partir du pourcentage servi par la machine.
    public var partMemoire: Double? {
        guard let pourcentage = memPct else { return nil }
        return min(max(Double(pourcentage) / 100, 0), 1)
    }
}
