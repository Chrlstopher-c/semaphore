import Foundation

// Le vocabulaire d'une session ccremote v2, tel que le relais l'envoie (miroir de `commun/session.ts` du dépôt
// ccremote). Les noms de champs sont ceux du JSON : toute divergence casserait le décodage en silence.

public enum StatutSession: String, Codable, Sendable, CaseIterable {
    case demarrage, travail, compaction, attente, question, terminee, erreur, fermee

    /// Une session qui travaille : le point pulse, le composeur prévient que le message attendra la fin du tour.
    public var enActivite: Bool { self == .demarrage || self == .travail || self == .compaction }

    public var libelle: String {
        switch self {
        case .demarrage: return "Démarre"
        case .travail: return "Travaille"
        case .compaction: return "Compacte"
        case .attente: return "En attente"
        case .question: return "Question"
        case .terminee: return "Objectif atteint"
        case .erreur: return "Erreur"
        case .fermee: return "Fermée"
        }
    }
}

public struct Projet: Codable, Sendable, Hashable {
    public let machine: String
    public let chemin: String
    public let nom: String

    public init(machine: String, chemin: String, nom: String) {
        self.machine = machine
        self.chemin = chemin
        self.nom = nom
    }
}

public struct Contexte: Codable, Sendable, Equatable {
    public let tokens: Int
    public let max: Int

    /// Part de la fenêtre relue à chaque tour. Au-delà de 0,35 (seuil dur du poste), la session coûte cher.
    public var ratio: Double { max > 0 ? Double(tokens) / Double(max) : 0 }
}

public struct Session: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let machine: String
    public let projet: Projet
    public let cwd: String
    public let titre: String
    public let objectif: String?
    public let modele: String
    public let compte: String
    public let autonomie: Bool
    public let statut: StatutSession
    public let contexte: Contexte
    public let etapes: Int
    public let compactions: Int
    public let claudeSessionId: String?
    public let tmux: String?
    public let attachee: Bool
    public let pilotee: Bool
    /// Vivante dans un terminal ordinaire, hors tmux : suivie en lecture seule (absent des relais anciens).
    public let terminal: Bool?
    public let creeLe: String
    public let majLe: String

    /// Pilotable à distance : elle a un tmux. Une session de terminal est vivante mais se lit seulement.
    public var ouverte: Bool { tmux != nil }
    public var vivante: Bool { tmux != nil || terminal == true }
}
