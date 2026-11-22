import Foundation

// Le vocabulaire d'une session ccremote v2, tel que le relais l'envoie (miroir de `commun/session.ts` du dépôt
// ccremote). Les noms de champs sont ceux du JSON : toute divergence casserait le décodage en silence.
// Décodage tolérant : un statut inconnu devient `.attente`, un champ facultatif mal formé devient absent.

public enum StatutSession: String, Codable, Sendable, CaseIterable {
    case demarrage, travail, compaction, attente, question, terminee, erreur, fermee

    /// Un statut qu'une version plus récente du relais ajoute : on le lit comme une session en attente.
    public init(from decodeur: Decoder) throws {
        let brut = try decodeur.singleValueContainer().decode(String.self)
        self = StatutSession(rawValue: brut) ?? .attente
    }

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

/// Mode de permission d'une session SDK. `defaut` = raw "default" (le mode standard, pas le bypass).
public enum ModeSession: String, Codable, Sendable, CaseIterable {
    case bypassPermissions, defaut = "default", acceptEdits, plan, auto
}

/// Effort de raisonnement d'une session SDK ; absent = défaut du modèle.
public enum EffortSession: String, Codable, Sendable, CaseIterable {
    case low, medium, high, xhigh, max
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

/// Une demande de permission d'outil (mode autre que bypass) : Autoriser, Toujours, Refuser.
public struct PermissionDialogue: Codable, Sendable, Equatable {
    public let outil: String
    public let entree: String
    public let suggestion: Bool
}

/// Un dialogue du TUI qui attend une réponse (AskUserQuestion, permission, validation de plan), relevé à l'écran du
/// pane par le poste : une question à la fois, comme au clavier.
public struct Dialogue: Codable, Sendable, Equatable {
    public struct Option: Codable, Sendable, Equatable {
        public let libelle: String
        public let description: String
    }

    public let id: String
    public let titre: String
    public let options: [Option]
    /// Cases à cocher (AskUserQuestion multiSelect).
    public let multiple: Bool
    /// L'option « Type something » : réponse libre.
    public let saisie: Int?
    public let coches: [Int]
    public let permission: PermissionDialogue?

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titre = try c.decode(String.self, forKey: .titre)
        options = try c.decode([Option].self, forKey: .options)
        multiple = try c.decode(Bool.self, forKey: .multiple)
        saisie = c.entierFacultatif(.saisie)
        coches = try c.decode([Int].self, forKey: .coches)
        permission = c.facultatif(PermissionDialogue.self, .permission)
    }
}

/// Choix unique : `index`. Choix multiple : `cases` (état voulu de toutes les cases). `texte` : réponse libre.
public struct ReponseDialogue: Codable, Sendable, Equatable {
    public let id: String
    public let index: Int?
    public let cases: [Int]?
    public let texte: String?

    public init(id: String, index: Int? = nil, cases: [Int]? = nil, texte: String? = nil) {
        self.id = id
        self.index = index
        self.cases = cases
        self.texte = texte
    }
}

/// Mode rapide (SDK `fastMode`) : `etat` et `raison` tels que le SDK les rapporte, `compatible` : le modèle l'accepte.
public struct ModeRapide: Codable, Sendable, Equatable {
    public let demande: Bool
    public let etat: String?
    public let raison: String?
    public let compatible: Bool?
}

/// Ultracode (clé de session, pas un niveau d'effort) : `demande` ce que Chris veut, `actif` ce que le SDK applique.
public struct ModeUltracode: Codable, Sendable, Equatable {
    public let demande: Bool
    public let actif: Bool
    public let disponible: Bool?
}

/// Session suivie depuis un compte (Remote Control, moteur `claude_ai`) : compte, id claude.ai, connexion.
public struct SessionDistante: Codable, Sendable, Equatable {
    public let compte: String
    public let idDistant: String
    public let connexion: String
    public let probleme: String?
}

public struct Session: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let machine: String
    public let projet: Projet
    public let cwd: String
    public let titre: String
    public let objectif: String?
    public let modele: String
    public let modeleNom: String?
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
    /// Dialogue du TUI en attente d'une réponse (absent des relais anciens).
    public let dialogue: Dialogue?
    /// `sdk`, `tmux` ou `claude_ai` ; absent = tmux (postes antérieurs).
    public let moteur: String?
    public let mode: String?
    public let effort: String?
    public let rapide: ModeRapide?
    public let ultracode: ModeUltracode?
    /// Calculé par le relais : ISO de la dernière activité quand le tour est fini depuis le seuil d'inactivité.
    public let inactiveDepuis: String?
    public let archivee: Bool?
    public let epinglee: Bool?
    public let nonLue: Bool?
    public let distant: SessionDistante?
    public let creeLe: String
    public let majLe: String

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        machine = try c.decode(String.self, forKey: .machine)
        projet = try c.decode(Projet.self, forKey: .projet)
        cwd = try c.decode(String.self, forKey: .cwd)
        titre = try c.decode(String.self, forKey: .titre)
        objectif = c.facultatif(String.self, .objectif)
        modele = try c.decode(String.self, forKey: .modele)
        modeleNom = c.facultatif(String.self, .modeleNom)
        compte = try c.decode(String.self, forKey: .compte)
        autonomie = try c.decode(Bool.self, forKey: .autonomie)
        statut = try c.decode(StatutSession.self, forKey: .statut)
        contexte = try c.decode(Contexte.self, forKey: .contexte)
        etapes = try c.entier(.etapes)
        compactions = try c.entier(.compactions)
        claudeSessionId = c.facultatif(String.self, .claudeSessionId)
        tmux = c.facultatif(String.self, .tmux)
        attachee = try c.decode(Bool.self, forKey: .attachee)
        pilotee = try c.decode(Bool.self, forKey: .pilotee)
        terminal = c.facultatif(Bool.self, .terminal)
        dialogue = c.facultatif(Dialogue.self, .dialogue)
        moteur = c.facultatif(String.self, .moteur)
        mode = c.facultatif(String.self, .mode)
        effort = c.facultatif(String.self, .effort)
        rapide = c.facultatif(ModeRapide.self, .rapide)
        ultracode = c.facultatif(ModeUltracode.self, .ultracode)
        inactiveDepuis = c.facultatif(String.self, .inactiveDepuis)
        archivee = c.facultatif(Bool.self, .archivee)
        epinglee = c.facultatif(Bool.self, .epinglee)
        nonLue = c.facultatif(Bool.self, .nonLue)
        distant = c.facultatif(SessionDistante.self, .distant)
        creeLe = try c.decode(String.self, forKey: .creeLe)
        majLe = try c.decode(String.self, forKey: .majLe)
    }

    /// Pilotable à distance : elle a un tmux. Une session de terminal est vivante mais se lit seulement.
    public var ouverte: Bool { tmux != nil }
    public var vivante: Bool { tmux != nil || terminal == true }

    public var modeSession: ModeSession? { mode.flatMap { ModeSession(rawValue: $0) } }
    public var effortSession: EffortSession? { effort.flatMap { EffortSession(rawValue: $0) } }
}
