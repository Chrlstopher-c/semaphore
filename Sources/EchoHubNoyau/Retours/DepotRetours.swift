import Foundation

/// Le verdict de Chris sur une réponse (`backend/retours`) : il nourrit le corpus d'exemples.
public enum Verdict: String, Sendable, Codable, CaseIterable {
    case positif, negatif, correction, meilleure, pire
}

/// Pourquoi une réponse est mauvaise : les huit raisons du web, dans son ordre.
public enum RaisonRetour: String, Sendable, Codable, CaseIterable {
    case accrocheFaible = "accroche_faible", ton, faitInvente = "fait_invente", clicheIa = "cliche_ia"
    case francais, generique, horsBrief = "hors_brief", structure

    public var libelle: String {
        switch self {
        case .accrocheFaible: "Accroche faible"
        case .ton: "Ton à côté"
        case .faitInvente: "Fait inventé"
        case .clicheIa: "Cliché / ton IA"
        case .francais: "Français maladroit"
        case .generique: "Trop générique"
        case .horsBrief: "Hors brief"
        case .structure: "Structure du canal"
        }
    }
}

/// Les verdicts d'une conversation, par message. Ceux de Claude restent à part.
public struct ResumeRetours: Sendable, Equatable {
    public var parMessage: [String: Verdict]
    public var raisonsParMessage: [String: [RaisonRetour]]
    public var claudeParMessage: [String: Verdict]

    public init(parMessage: [String: Verdict] = [:], raisonsParMessage: [String: [RaisonRetour]] = [:],
                claudeParMessage: [String: Verdict] = [:]) {
        self.parMessage = parMessage
        self.raisonsParMessage = raisonsParMessage
        self.claudeParMessage = claudeParMessage
    }
}

/// Corps de `POST /retours`.
public struct DemandeRetour: Sendable, Encodable, Equatable {
    public let conversationId: String
    public let messageId: String
    public let verdict: Verdict
    public let correction: String?
    public let raisons: [RaisonRetour]

    public init(conversationId: String, messageId: String, verdict: Verdict, correction: String?, raisons: [RaisonRetour]) {
        self.conversationId = conversationId
        self.messageId = messageId
        self.verdict = verdict
        self.correction = correction
        self.raisons = raisons
    }
}

public enum Retours {
    /// Retoucher le verdict déjà posé le retire (comme le web), sauf une correction ou un choix de raisons.
    public static func retire(actuel: Verdict?, nouveau: Verdict, raisons: [RaisonRetour]?) -> Bool {
        nouveau == actuel && nouveau != .correction && raisons == nil
    }

    /// Le texte livré, sans le raisonnement : c'est lui qu'on corrige.
    public static func texteFinal(_ contenu: String) -> String {
        guard let fin = contenu.range(of: "</think>", options: .backwards) else {
            return contenu.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(contenu[fin.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Clés de dictionnaire décodées à la main : la conversion snake_case toucherait les identifiants de messages.
    static func resume(_ donnees: Data) throws -> ResumeRetours {
        guard let objet = try JSONSerialization.jsonObject(with: donnees) as? [String: Any] else {
            throw ErreurRelais.reponseIllisible("résumé des retours")
        }
        func verdicts(_ cle: String) -> [String: Verdict] {
            ((objet[cle] as? [String: String]) ?? [:]).compactMapValues(Verdict.init(rawValue:))
        }
        let raisons = ((objet["raisons_par_message"] as? [String: [String]]) ?? [:])
            .mapValues { $0.compactMap(RaisonRetour.init(rawValue:)) }
        return ResumeRetours(parMessage: verdicts("par_message"), raisonsParMessage: raisons,
                             claudeParMessage: verdicts("claude_par_message"))
    }
}

public struct DepotRetours: Sendable {
    let client: ClientEchoHub

    public init(client: ClientEchoHub) { self.client = client }

    public func resume(_ conversationId: String) async throws -> ResumeRetours {
        try Retours.resume(try await client.brut("GET", "retours?conversation_id=\(DepotProjets.encoder(conversationId))"))
    }

    public func noter(_ demande: DemandeRetour) async throws {
        try await client.executer("POST", "retours", corps: try CodageJSON.encodeur().encode(demande))
    }

    public func retirer(_ messageId: String) async throws {
        try await client.executer("DELETE", "retours/\(DepotProjets.encoder(messageId))")
    }
}
