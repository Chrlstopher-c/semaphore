import Foundation

/// Réponse d'une route `pi-web` qui traverse le WebSocket vers le poste de
/// travail (`pc_client.ws_cmd`).
///
/// `☠` TROISIÈME forme d'absence du PC, à ne pas confondre avec l'enveloppe H-75
/// du harness : ici, PC éteint = **HTTP 200** avec `pc_online: false`,
/// `status: "error"`, `message: "PC unreachable"`. Aucune enveloppe, aucun
/// `stale`, aucune donnée datée — le registre du Pi ne couvre pas ces routes.
public protocol ReponsePoste: Decodable, Sendable {
    var pcOnline: Bool { get }
    /// `ok`, `error`, ou un statut propre à la commande (`launched`, `killed`…).
    var status: String { get }
    var message: String? { get }
}

/// Les trois issues d'un appel au poste de travail.
public enum LecturePoste<Charge: ReponsePoste>: Sendable {
    case fraiche(Charge)
    /// Le poste ne répond pas au WebSocket LAN. Régime nominal quand il dort.
    case pcAbsent(message: String)
    /// Le poste a répondu et a REFUSÉ — session inconnue, commande impossible.
    /// Distinct de l'absence : ici, quelque chose a écouté et dit non.
    case refus(String)
    case echec(ErreurApi)
}

extension DecodeurContrat {
    /// Traduit une réponse d'une route `pi-web` adossée au poste de travail.
    public static func poste<Charge: ReponsePoste>(
        _ type: Charge.Type,
        statut: Int,
        corps: Data
    ) -> LecturePoste<Charge> {
        switch nu(Charge.self, statut: statut, corps: corps) {
        case .failure(let erreur):
            return .echec(erreur)
        case .success(let charge):
            if !charge.pcOnline { return .pcAbsent(message: charge.message ?? "PC injoignable") }
            if charge.status == "error" { return .refus(charge.message ?? "ordre refusé par le poste") }
            return .fraiche(charge)
        }
    }
}

/// `GET /api/status`.
public struct StatutPosteApi: ReponsePoste, Hashable {
    public let pcOnline: Bool
    public let status: String
    public let message: String?
    /// Une session `claude` tourne dans tmux sur le poste.
    public let claudeRunning: Bool?

    enum CodingKeys: String, CodingKey {
        case pcOnline = "pc_online"
        case status, message
        case claudeRunning = "claude_running"
    }
}

/// `GET /api/sessions`.
public struct SessionsPosteApi: ReponsePoste {
    public let pcOnline: Bool
    public let status: String
    public let message: String?
    public let sessions: [SessionTmuxApi]?

    enum CodingKeys: String, CodingKey {
        case pcOnline = "pc_online"
        case status, message, sessions
    }
}

public struct SessionTmuxApi: Decodable, Sendable, Hashable, Identifiable {
    public let name: String
    /// `☠` Epoch en SECONDES — tmux les rend ainsi. Tout le reste du contrat est
    /// en millisecondes : les mélanger a déjà produit un « reset dans
    /// 495278229 h » sur ce produit.
    public let created: Int
    public let attached: Bool

    public var id: String { name }
}

/// `GET /api/capture?session=` — les dernières lignes du panneau tmux.
public struct CapturePosteApi: ReponsePoste {
    public let pcOnline: Bool
    public let status: String
    public let message: String?
    /// Contient des séquences d'échappement ANSI : à nettoyer avant affichage.
    public let output: String?

    enum CodingKeys: String, CodingKey {
        case pcOnline = "pc_online"
        case status, message, output
    }
}

/// Réponse d'un ordre simple au poste : `launch`, `kill`, `send`, `shutdown`.
public struct OrdrePosteApi: ReponsePoste, Hashable {
    public let pcOnline: Bool
    /// `launched`, `already_running`, `killed`, `shutting_down`, `ok`, `error`.
    public let status: String
    public let message: String?
    public let session: String?

    enum CodingKeys: String, CodingKey {
        case pcOnline = "pc_online"
        case status, message, session
    }
}

/// `GET /api/claude-accounts` — les comptes Claude Code installés sur le poste.
///
/// `☠` Rien à voir avec `AccountApi` du harness : celui-ci décrit les profils
/// `CLAUDE_CONFIG_DIR` du poste, celui-là les quotas mesurés du registre.
public struct ComptesClaudeApi: ReponsePoste {
    public let pcOnline: Bool
    public let status: String
    public let message: String?
    public let accounts: [CompteClaudeApi]?

    enum CodingKeys: String, CodingKey {
        case pcOnline = "pc_online"
        case status, message, accounts
    }
}

public struct CompteClaudeApi: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let label: String
    public let active: Bool
}

/// `POST /api/claude-accounts/switch`.
public struct BasculeCompteApi: ReponsePoste, Hashable {
    public let pcOnline: Bool
    /// `ok`, `already_active`, `error`.
    public let status: String
    public let message: String?
    public let account: String?
    /// Les sessions tmux redémarrées pour charger le nouveau compte.
    public let restartedSessions: [String]?

    enum CodingKeys: String, CodingKey {
        case pcOnline = "pc_online"
        case status, message, account
        case restartedSessions = "restarted_sessions"
    }
}

/// `POST /api/wake` — le paquet magique part du Pi, sans réponse du poste.
/// `☠` `{ "status": "sent" }` dit que le paquet est PARTI, jamais que la machine
/// s'allume. Seul `GET /api/status` peut le confirmer, quelques dizaines de
/// secondes plus tard.
public struct ReveilApi: Decodable, Sendable, Hashable {
    public let status: String
}

/// `GET /api/config`.
public struct ConfigApi: Decodable, Sendable, Hashable {
    public let pcHost: String
    public let pcMac: String
    public let defaultModel: String
    /// Modèles de l'agent Cerebras de `pi-web` — PAS le catalogue Claude du
    /// harness (`GET /modeles`). Deux listes, deux usages.
    public let models: [String]

    enum CodingKeys: String, CodingKey {
        case pcHost = "pc_host"
        case pcMac = "pc_mac"
        case defaultModel = "default_model"
        case models
    }
}

/// `POST /api/agent/context-usage`.
public struct ContexteAgentApi: Decodable, Sendable, Hashable {
    public let model: String
    public let tokensUsed: Int
    public let tokensLimit: Int

    enum CodingKeys: String, CodingKey {
        case model
        case tokensUsed = "tokens_used"
        case tokensLimit = "tokens_limit"
    }
}
