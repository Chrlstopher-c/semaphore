import Foundation

// Responsabilité : un message poussé par le relais sur le WebSocket `/api/flux` (miroir de `MessageClient` dans
// `commun/api-clients.ts`). Un type inconnu, ou un message mal formé, devient `.inconnu` : il ne coupe jamais le flux.

public enum MessageClient: Decodable, Sendable, Equatable {
    case evenement(EvenementDate)
    case flux(sessionId: String, bloc: String, delta: String, genre: String?, agent: String?)
    case session(Session)
    case supprimee(id: String)
    case machine(Machine)
    case notification(NotificationRelais)
    case filModifie(sessionId: String)
    case inconnu(type: String)
}

extension MessageClient {
    fileprivate enum Cle: String, CodingKey {
        case type, evenement, sessionId, bloc, delta, genre, agent, session, id, machine, notification
    }

    public init(from decodeur: Decoder) throws {
        guard let c = try? decodeur.container(keyedBy: Cle.self) else {
            self = .inconnu(type: "")
            return
        }
        let type = (try? c.decode(String.self, forKey: .type)) ?? ""
        let trouve: MessageClient? = (try? Self.fil(type, c)) ?? (try? Self.objet(type, c))
        self = trouve ?? .inconnu(type: type)
    }

    /// Messages d'événement, de delta ou de signal de fil ; `nil` si le type n'est pas de ce groupe.
    private static func fil(_ type: String, _ c: KeyedDecodingContainer<Cle>) throws -> MessageClient? {
        switch type {
        case "evenement":
            return .evenement(try c.decode(EvenementDate.self, forKey: .evenement))
        case "flux":
            return .flux(sessionId: try c.decode(String.self, forKey: .sessionId),
                         bloc: try c.decode(String.self, forKey: .bloc),
                         delta: try c.decode(String.self, forKey: .delta),
                         genre: c.facultatif(String.self, .genre), agent: c.facultatif(String.self, .agent))
        case "fil_modifie":
            return .filModifie(sessionId: try c.decode(String.self, forKey: .sessionId))
        default:
            return nil
        }
    }

    /// Les messages qui portent un objet du parc ou une notification ; `nil` si le type n'est pas de ce groupe.
    private static func objet(_ type: String, _ c: KeyedDecodingContainer<Cle>) throws -> MessageClient? {
        switch type {
        case "session":
            return .session(try c.decode(Session.self, forKey: .session))
        case "supprimee":
            return .supprimee(id: try c.decode(String.self, forKey: .id))
        case "machine":
            return .machine(try c.decode(Machine.self, forKey: .machine))
        case "notification":
            return .notification(try c.decode(NotificationRelais.self, forKey: .notification))
        default:
            return nil
        }
    }
}
