import Foundation

/// Premier événement du flux : dit quel message assistant va s'écrire, et où
/// il s'accroche dans l'arbre. Sans lui, l'app devrait relire la conversation
/// entière pour savoir où poser le texte qui arrive.
public struct EvenementDebut: Sendable, Decodable, Equatable {
    public let conversationId: String
    public let messageId: String
    public let modeleId: String?
    public let parentId: String?
    /// Le message utilisateur que ce tour vient de créer, s'il en a créé un —
    /// un rejeu de réponse n'en crée aucun.
    public let messageUtilisateurId: String?
}

/// Dernier événement : ce qui a été mesuré, et pourquoi ça s'est arrêté.
public struct EvenementFin: Sendable, Decodable, Equatable {
    public let messageId: String
    public let tokensGeneres: Int?
    public let tokensParSeconde: Double?
    public let dureeMs: Int
    public let interrompu: Bool
}

/// Une erreur survenue APRÈS l'ouverture du flux. Le statut HTTP est déjà
/// parti : c'est la seule façon pour le serveur de dire que ça a raté.
public struct EvenementErreur: Sendable, Decodable, Equatable {
    public let code: String?
    public let message: String
    public let remediation: String?
}

/// L'enveloppe de l'événement `compaction` : le contrat pose la balise sous la
/// clé `compaction`, jamais à plat. On décode l'enveloppe, on rend la balise.
public struct EvenementCompaction: Sendable, Decodable, Equatable {
    public let compaction: InfoCompaction
}

/// Ce qu'une trame SSE d'EchoHub peut porter.
public enum EvenementFlux: Sendable, Equatable {
    case debut(EvenementDebut)
    case fragment(String)
    /// La balise émise AVANT les fragments du tour dont la génération a déclenché
    /// la compaction. Elle porte le `message_id` du message assistant à venir —
    /// celui qu'a annoncé `debut` — au-dessus duquel se pose la balise.
    case compaction(InfoCompaction)
    case fin(EvenementFin)
    case erreur(EvenementErreur)
    /// La sentinelle `data: [DONE]` du flux `/api/inference/generer`. Le flux
    /// `chat` ne l'écrit pas ; on la reconnaît parce que les deux routes
    /// existent et que rien ne garantit qu'une future version n'y passe pas.
    case termine
}

/// Traduit une trame en événement. Rend `nil` sur ce qui n'en est pas un —
/// battement de cœur, trame vide, charge illisible : le flux continue, il ne
/// meurt pas sur une trame qu'on ne comprend pas.
public enum LectureEvenement {
    private struct Enveloppe: Decodable { let type: String }

    public static func lire(_ trame: TrameSSE) -> EvenementFlux? {
        let charge = trame.donnees.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !charge.isEmpty else { return nil }
        guard charge != "[DONE]" else { return .termine }
        guard let donnees = charge.data(using: .utf8) else {
            Journal.echec("trame SSE non décodable en UTF-8 (\(charge.count) caractères)")
            return nil
        }
        let decodeur = CodageJSON.decodeur()
        // Le `type` du JSON fait foi, pas le champ `event:` — voir `TrameSSE`.
        guard let type = try? decodeur.decode(Enveloppe.self, from: donnees).type else {
            Journal.echec("trame SSE sans champ « type » : \(charge.prefix(120))")
            return nil
        }
        return construire(type: type, donnees: donnees, decodeur: decodeur, charge: charge)
    }

    private static func construire(
        type: String, donnees: Data, decodeur: JSONDecoder, charge: String
    ) -> EvenementFlux? {
        do {
            switch type {
            case "debut": return .debut(try decodeur.decode(EvenementDebut.self, from: donnees))
            case "fragment": return .fragment(try decodeur.decode(Fragment.self, from: donnees).texte)
            case "compaction":
                return .compaction(try decodeur.decode(EvenementCompaction.self, from: donnees).compaction)
            case "fin": return .fin(try decodeur.decode(EvenementFin.self, from: donnees))
            case "erreur": return .erreur(try decodeur.decode(EvenementErreur.self, from: donnees))
            default:
                Journal.note("événement SSE inconnu ignoré : « \(type) »")
                return nil
            }
        } catch {
            Journal.echec("événement « \(type) » illisible : \(error) — \(charge.prefix(120))")
            return nil
        }
    }

    private struct Fragment: Decodable { let texte: String }
}
