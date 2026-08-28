import Foundation

/// Le seul journal de Vigie.
///
/// `☠` Il n'y a ni débogueur, ni simulateur, ni preview sur cette chaîne : la
/// sortie standard relayée par `idevicesyslog` est le seul instrument de
/// diagnostic. Un `catch` muet dans ce projet est donc littéralement invisible,
/// pas seulement discret.
public enum NiveauTrace: Int, Sendable, Comparable {
    case detail = 0
    case info = 1
    case erreur = 2
    /// Ferme le journal. Ne sert qu'aux tests.
    case muet = 3

    public static func < (gauche: NiveauTrace, droite: NiveauTrace) -> Bool {
        gauche.rawValue < droite.rawValue
    }
}

public enum Trace {
    /// `nonisolated(unsafe)` assumé : écrit une seule fois au démarrage, avant
    /// toute tâche concurrente. Un verrou pour un réglage de journal coûterait
    /// plus cher que le risque qu'il couvre.
    public nonisolated(unsafe) static var seuil: NiveauTrace = .info

    public static func detail(_ domaine: String, _ message: String) {
        ecrire(.detail, domaine, message)
    }

    public static func info(_ domaine: String, _ message: String) {
        ecrire(.info, domaine, message)
    }

    public static func erreur(_ domaine: String, _ message: String) {
        ecrire(.erreur, domaine, message)
    }

    /// Variante qui accole la cause : la forme à employer dans tout `catch`.
    public static func erreur(_ domaine: String, _ message: String, _ cause: Error) {
        ecrire(.erreur, domaine, "\(message) — \(cause)")
    }

    private static func ecrire(_ niveau: NiveauTrace, _ domaine: String, _ message: String) {
        guard niveau >= seuil else { return }
        print("\(horodatage()) [\(marque(niveau))][\(domaine)] \(message)")
    }

    private static func marque(_ niveau: NiveauTrace) -> String {
        switch niveau {
        case .detail: return "·"
        case .info: return "i"
        case .erreur: return "✗"
        case .muet: return " "
        }
    }

    /// HH:MM:SS calculé à la main plutôt qu'avec un `DateFormatter` : aucun
    /// formateur de Foundation n'est `Sendable`, et une trace ne doit jamais
    /// être la raison d'un verrou ou d'un avertissement de concurrence.
    private static func horodatage() -> String {
        let secondes = Int(Date().timeIntervalSince1970)
        let dansLeJour = secondes % 86_400
        let heures = dansLeJour / 3600
        let minutes = (dansLeJour % 3600) / 60
        return String(format: "%02d:%02d:%02d", heures, minutes, dansLeJour % 60)
    }
}
