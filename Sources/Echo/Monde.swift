#if canImport(SwiftUI)
import Foundation

/// Les mondes du centre de contrôle. Chacun est une application entière,
/// avec sa charte, sa barre et son cycle de vie ; le pupitre ne fait que
/// choisir lequel est devant.
///
/// `☠` C'est le SEUL point de couplage entre les deux modules. Aucun écran de
/// Vigie ne connaît EchoHub, et réciproquement — un fichier qui importerait
/// les deux verrait quinze types homonymes entrer en collision.
public enum Monde: String, CaseIterable, Identifiable, Hashable, Sendable {
    /// ccremote — le parc d'agents, les décisions, le terminal.
    case quart
    /// EchoHub — le modèle local, ses conversations, sa machine.
    case machine
    /// Saily — l'inbox personnelle de capture, synchronisée avec le PC.
    case saily
    /// Duplex — l'écoute sur le téléphone du son qui sort du PC.
    case duplex

    public var id: String { rawValue }

    public var titre: String {
        switch self {
        case .quart: return "Quart"
        case .machine: return "Machine"
        case .saily: return "Saily"
        case .duplex: return "Duplex"
        }
    }

    /// Symboles anciens (iOS 14 au plus tard) : un symbole absent se rend en
    /// carré vide, sans erreur ni avertissement.
    public var symbole: String {
        switch self {
        case .quart: return "moon.stars.fill"
        case .machine: return "cpu"
        case .saily: return "tray.full.fill"
        case .duplex: return "hifispeaker.2.fill"
        }
    }
}
#endif
