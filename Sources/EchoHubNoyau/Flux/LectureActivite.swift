import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Ce que la ligne d'activité dit du moteur (`progression.ts` du web).
public struct RepereActivite: Sendable, Equatable {
    public enum Ton: Sendable { case neutre, actif, alerte }
    public let libelle: String
    public let ton: Ton
    public let montrerJetons: Bool
    public let montrerOutil: Bool

    /// Sans nouvelle du moteur depuis 4 s, la ligne le dit : un silence se voit, il ne se devine pas.
    public static let silence: TimeInterval = 4

    public init(_ activite: ActiviteMoteur, silencieux: Bool) {
        let calme = activite.phase == "lecture" || activite.phase == "compaction"
        if silencieux && activite.phase != "execution" && activite.phase != "lecture" {
            self.init(libelle: "Aucune nouvelle du moteur", ton: .alerte, montrerJetons: false, montrerOutil: !calme)
            return
        }
        let (libelle, ton): (String, Ton) = switch activite.phase {
        case "reflexion": ("Réflexion", .neutre)
        case "texte": ("Rédaction", .actif)
        case "outil": ("Écrit un appel", .actif)
        case "execution": ("Exécute", .alerte)
        case "lecture": ("Relit le contexte", .neutre)
        case "compaction": ("Compacte le contexte", .actif)
        default: (activite.phase, .neutre)
        }
        self.init(libelle: libelle, ton: ton, montrerJetons: !calme && activite.tokens > 0, montrerOutil: !calme)
    }

    init(libelle: String, ton: Ton, montrerJetons: Bool, montrerOutil: Bool) {
        self.libelle = libelle
        self.ton = ton
        self.montrerJetons = montrerJetons
        self.montrerOutil = montrerOutil
    }

    /// `12 s`, `3 min 05 s`, `1 h 02 min`.
    public static func duree(_ secondes: TimeInterval) -> String {
        let s = max(0, Int(secondes))
        if s < 60 { return "\(s) s" }
        let m = s / 60
        if m < 60 { return "\(m) min \(String(format: "%02d", s % 60)) s" }
        return "\(m / 60) h \(String(format: "%02d", m % 60)) min"
    }
}

/// Une tâche du plan de l'agent, lue dans les deux langues du contrat.
public enum EtatTache: Sendable, Equatable {
    case aFaire, enCours, fait, bloque, abandonne

    public init(_ brut: String) {
        switch brut {
        case "in_progress", "en_cours": self = .enCours
        case "done", "fait": self = .fait
        case "blocked", "bloque": self = .bloque
        case "abandoned", "abandonne": self = .abandonne
        default: self = .aFaire
        }
    }

    /// ○ ◐ ✓ ! – comme le plan du web.
    public var marque: String {
        switch self {
        case .aFaire: "○"
        case .enCours: "◐"
        case .fait: "✓"
        case .bloque: "!"
        case .abandonne: "–"
        }
    }
}

extension ClientEchoHub {
    /// Passe une commande shell de l'agent en fond, ou l'arrête (tue son groupe de processus).
    public func agirSurCommande(_ identifiant: String, geste: GesteCommande) async throws {
        try await executer("POST", "commandes/\(identifiant)/\(geste.rawValue)")
    }
}

public enum GesteCommande: String, Sendable {
    case fond, arreter
}
