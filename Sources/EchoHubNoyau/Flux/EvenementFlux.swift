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
/// Instantané de l'activité du moteur (`activite`), au plus deux par seconde, jamais persisté.
public struct ActiviteMoteur: Sendable, Decodable, Equatable {
    /// `reflexion`, `texte`, `outil`, `execution`, `lecture`, `compaction`.
    public let phase: String
    public let tokens: Int
    public let tokensParSeconde: Double
    public let outil: OutilEnDirect?
    public let taches: [TacheAgent]?
    public let contexte: Jauge?
    public let lecture: Avancement?
    public let debut: Date?

    public struct Jauge: Sendable, Decodable, Equatable {
        public let tokens: Int
        public let total: Int
    }

    public struct Avancement: Sendable, Decodable, Equatable {
        public let faits: Int
        public let total: Int
    }
}

/// Appel d'outil en cours d'écriture ou d'exécution.
public struct OutilEnDirect: Sendable, Decodable, Equatable {
    public let nom: String
    public let chemin: String?
    public let caracteres: Int
}

/// Tâche du plan de l'agent ; `etat` en anglais depuis le 25/11, en français avant.
public struct TacheAgent: Sendable, Decodable, Equatable {
    public let titre: String
    public let etat: String
}

/// État d'une commande du chat (`/compact`), diffusé tant qu'elle tourne.
public struct EtatCommande: Sendable, Decodable, Equatable {
    public let id: String
    public let nom: String
    /// `en_cours`, `termine`, `echec`.
    public let etat: String
    public let etape: String
    public let detail: String
    public let tokens: Int?
    public let tokensParSeconde: Double?
    public let dureeMs: Int
    public let erreur: String?
}

/// Sortie en direct d'une commande shell de l'agent (`commande_shell`) : un AJOUT, pas la sortie entière.
public struct SortieCommandeShell: Sendable, Decodable, Equatable {
    public let commandeId: String
    public let appelId: String
    /// `en_cours`, `en_fond`, `terminee`, `arretee`.
    public let etat: String
    public let sortie: String
    public let code: Int?
}

public enum EvenementFlux: Sendable, Equatable {
    case debut(EvenementDebut)
    case fragment(String)
    /// La balise émise AVANT les fragments du tour dont la génération a déclenché
    /// la compaction. Elle porte le `message_id` du message assistant à venir —
    /// celui qu'a annoncé `debut` — au-dessus duquel se pose la balise.
    case compaction(InfoCompaction)
    case fin(EvenementFin)
    case erreur(EvenementErreur)
    case activite(ActiviteMoteur)
    case commande(EtatCommande)
    case commandeShell(SortieCommandeShell)
    /// La sentinelle `data: [DONE]` du flux `/api/inference/generer`. Le flux
    /// `chat` ne l'écrit pas ; on la reconnaît parce que les deux routes
    /// existent et que rien ne garantit qu'une future version n'y passe pas.
    case termine

    /// Une coupure de transport que le flux a convertie en erreur (code `transport`) : la génération
    /// continue peut-être sur le PC, on s'y raccroche au lieu de peindre une erreur.
    public var estCoupureTransport: Bool {
        if case .erreur(let erreur) = self { return erreur.code == EvenementErreur.codeTransport }
        return false
    }
}

extension EvenementErreur {
    public static let codeTransport = "transport"
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
            case "activite": return .activite(try decodeur.decode(Activite.self, from: donnees).activite)
            case "commande": return .commande(try decodeur.decode(Commande.self, from: donnees).commande)
            case "commande_shell":
                return .commandeShell(try decodeur.decode(SortieCommandeShell.self, from: donnees))
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
    private struct Activite: Decodable { let activite: ActiviteMoteur }
    private struct Commande: Decodable { let commande: EtatCommande }
}
