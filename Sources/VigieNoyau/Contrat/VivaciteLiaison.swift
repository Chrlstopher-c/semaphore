import Foundation

// Responsabilité : la vivacité d'une liaison longue durée (WebSocket de l'aiguilleur, flux direct du relais).
// Un ping à chaque échéance ; pas de pong dans le délai = liaison morte, à refaire. Le calcul est pur
// (MinuterieVivacite, le temps est passé en paramètre) ; l'acteur VivaciteLiaison le partage entre la veille et
// les pongs, qui arrivent d'un autre fil.

/// Délais de vivacité : un ping toutes les 15 s, un pong attendu dans les 10 s.
public enum DelaisVivacite {
    public static let intervalle: Duration = .seconds(15)
    public static let pong: Duration = .seconds(10)
}

/// Ce que la veille doit faire à un instant donné.
public enum ActionVivacite: Sendable, Equatable {
    case rien, ping, morte
}

/// Minuterie pure : rien n'est lu sur l'horloge, l'instant est toujours passé en paramètre (testable).
public struct MinuterieVivacite: Sendable, Equatable {
    public let intervalle: Duration
    public let delaiPong: Duration
    private(set) var prochainPing: ContinuousClock.Instant
    private(set) var pingEnvoye: ContinuousClock.Instant?

    public init(intervalle: Duration, delaiPong: Duration, depuis maintenant: ContinuousClock.Instant) {
        self.intervalle = intervalle
        self.delaiPong = delaiPong
        prochainPing = maintenant.advanced(by: intervalle)
    }

    /// Une trame ou un pong est arrivé : la liaison vit, le prochain ping se compte à partir d'ici.
    public mutating func recu(_ maintenant: ContinuousClock.Instant) {
        prochainPing = maintenant.advanced(by: intervalle)
        pingEnvoye = nil
    }

    public mutating func pingPartie(_ maintenant: ContinuousClock.Instant) {
        pingEnvoye = maintenant
    }

    /// Ping demandé tout de suite (retour au premier plan) : il part au prochain tour de la veille.
    public mutating func forcerPing(_ maintenant: ContinuousClock.Instant) {
        prochainPing = maintenant
        pingEnvoye = nil
    }

    public func action(_ maintenant: ContinuousClock.Instant) -> ActionVivacite {
        if let envoye = pingEnvoye {
            return maintenant >= envoye.advanced(by: delaiPong) ? .morte : .rien
        }
        return maintenant >= prochainPing ? .ping : .rien
    }

    /// Temps à dormir avant la prochaine décision.
    public func attente(_ maintenant: ContinuousClock.Instant) -> Duration {
        let echeance = pingEnvoye?.advanced(by: delaiPong) ?? prochainPing
        return max(maintenant.duration(to: echeance), .zero)
    }
}

/// La minuterie d'une liaison, partagée entre sa veille et les pongs (qui arrivent sur un autre fil).
public actor VivaciteLiaison {
    private var minuterie: MinuterieVivacite

    public init(intervalle: Duration = DelaisVivacite.intervalle, delaiPong: Duration = DelaisVivacite.pong) {
        minuterie = MinuterieVivacite(intervalle: intervalle, delaiPong: delaiPong, depuis: .now)
    }

    /// Une trame ou un pong est arrivé.
    public func recu() {
        minuterie.recu(.now)
    }

    public func pingPartie() {
        minuterie.pingPartie(.now)
    }

    /// Ping immédiat : la veille l'envoie au prochain tour.
    public func forcerPing() {
        minuterie.forcerPing(.now)
    }

    public func action() -> ActionVivacite {
        minuterie.action(.now)
    }

    public func attente() -> Duration {
        minuterie.attente(.now)
    }
}
