import Foundation

// Un événement du fil d'une session (miroir de `Evenement` dans `commun/session.ts`). Décodé sur le champ `type` ;
// un type inconnu (relais plus récent que l'app) devient `.inconnu` au lieu de faire échouer tout le fil.

public enum Evenement: Sendable, Equatable {
    case message(texte: String)
    case texte(texte: String, agent: String?)
    case reflexion(texte: String, agent: String?)
    case outil(id: String, nom: String, resume: String, detail: String, agent: String?)
    case resultatOutil(outilId: String, extrait: String, erreur: Bool, agent: String?)
    case sousAgent(id: String, description: String, modele: String, genre: String)
    case etape(resume: String, suite: String)
    case objectifAtteint(bilan: String)
    case question(question: String)
    case compaction(avant: Int, apres: Int, declencheur: String)
    case relance(raison: String)
    case tourFini(dureeMs: Int, contexte: Int)
    case erreur(message: String)
    case inconnu(type: String)
}

extension Evenement: Decodable {
    private enum Cle: String, CodingKey {
        case type, texte, agent, id, nom, resume, detail, outilId, extrait, erreur, description, modele, genre
        case suite, bilan, question, avant, apres, declencheur, raison, dureeMs, contexte, message
    }

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: Cle.self)
        let type = try c.decode(String.self, forKey: .type)
        func s(_ k: Cle) throws -> String { try c.decode(String.self, forKey: k) }
        func n(_ k: Cle) throws -> Int { try c.decode(Int.self, forKey: k) }
        let agent = try c.decodeIfPresent(String.self, forKey: .agent)
        switch type {
        case "message": self = .message(texte: try s(.texte))
        case "texte": self = .texte(texte: try s(.texte), agent: agent)
        case "reflexion": self = .reflexion(texte: try s(.texte), agent: agent)
        case "outil":
            self = .outil(id: try s(.id), nom: try s(.nom), resume: try s(.resume), detail: try s(.detail), agent: agent)
        case "resultat_outil":
            self = .resultatOutil(outilId: try s(.outilId), extrait: try s(.extrait),
                                  erreur: try c.decode(Bool.self, forKey: .erreur), agent: agent)
        case "sous_agent":
            self = .sousAgent(id: try s(.id), description: try s(.description), modele: try s(.modele), genre: try s(.genre))
        default: self = try Self.jalon(type, s: s, n: n)
        }
    }

    private static func jalon(_ type: String, s: (Cle) throws -> String, n: (Cle) throws -> Int) throws -> Evenement {
        switch type {
        case "etape": return .etape(resume: try s(.resume), suite: try s(.suite))
        case "objectif_atteint": return .objectifAtteint(bilan: try s(.bilan))
        case "question": return .question(question: try s(.question))
        case "compaction": return .compaction(avant: try n(.avant), apres: try n(.apres), declencheur: try s(.declencheur))
        case "relance": return .relance(raison: try s(.raison))
        case "tour_fini": return .tourFini(dureeMs: try n(.dureeMs), contexte: try n(.contexte))
        case "erreur": return .erreur(message: try s(.message))
        default: return .inconnu(type: type)
        }
    }
}

public struct EvenementDate: Decodable, Sendable, Equatable, Identifiable {
    public let seq: Int
    public let sessionId: String
    public let ts: String
    public let evt: Evenement

    public var id: Int { seq }

    public init(seq: Int, sessionId: String, ts: String, evt: Evenement) {
        self.seq = seq
        self.sessionId = sessionId
        self.ts = ts
        self.evt = evt
    }
}
