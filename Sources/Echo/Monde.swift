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
    /// Tamis — le tri de la photothèque, pour alléger iCloud.
    case tamis
    /// Iris — la caméra de l'iPhone prêtée aux PC comme webcam.
    case iris

    public var id: String { rawValue }

    /// Ce que fait le monde, en quelques mots, sous son nom dans la grille.
    public var role: String {
        switch self {
        case .quart: return "Agents"
        case .machine: return "Modèle local"
        case .saily: return "Capture"
        case .duplex: return "Son du PC"
        case .tamis: return "Photos"
        case .iris: return "Caméra des PC"
        }
    }

    public var titre: String {
        switch self {
        case .quart: return "Quart"
        case .machine: return "Machine"
        case .saily: return "Saily"
        case .duplex: return "Duplex"
        case .tamis: return "Tamis"
        case .iris: return "Iris"
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
        case .tamis: return "photo.stack.fill"
        case .iris: return "video.fill"
        }
    }
}
#endif
