import Foundation

/// Un PC récepteur tel que le relais Iris le présente : son nom, s'il veut le
/// flux (une application lit sa webcam virtuelle), le numéro de sa connexion au
/// relais, et les adresses du réseau local où il attend l'iPhone.
///
/// `☠` `session` change à chaque reconnexion du PC : une liaison ouverte vers
/// une session périmée vise un processus mort et doit être rouverte.
public struct Recepteur: Sendable, Equatable, Identifiable, Decodable {
    public let nom: String
    public let veut: Bool
    public let session: Int
    public let adresses: [String]

    public var id: String { nom }

    public init(nom: String, veut: Bool, session: Int, adresses: [String]) {
        self.nom = nom
        self.veut = veut
        self.session = session
        self.adresses = adresses
    }

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: CodingKeys.self)
        nom = try c.decode(String.self, forKey: .nom)
        veut = try c.decode(Bool.self, forKey: .veut)
        session = try c.decode(Int.self, forKey: .session)
        adresses = try c.decodeIfPresent([String].self, forKey: .adresses) ?? []
    }

    private enum CodingKeys: String, CodingKey { case nom, veut, session, adresses }
}

/// Ce que le relais envoie à la caméra. Tout type inconnu est ignoré, jamais
/// fatal : le relais sert aussi la page web, qui reçoit des messages WebRTC.
public enum MessageRelais: Sendable, Equatable {
    case recepteurs([Recepteur])
    case etat(de: String, texte: String)
    case ignore

    public static func lire(_ donnees: Data) -> MessageRelais {
        guard let enveloppe = try? JSONDecoder().decode(Enveloppe.self, from: donnees) else { return .ignore }
        switch enveloppe.type {
        case "recepteurs": return .recepteurs(enveloppe.liste ?? [])
        case "etat":
            guard let de = enveloppe.de, let texte = enveloppe.etat else { return .ignore }
            return .etat(de: de, texte: texte)
        default: return .ignore
        }
    }

    private struct Enveloppe: Decodable {
        let type: String
        let liste: [Recepteur]?
        let de: String?
        let etat: String?
    }
}

/// Ce que la caméra envoie : au relais (réglages, maintien) et au PC (poignée de main).
public enum MessageSortant {
    public static func reglages(cadrage: Cadrage) -> String {
        #"{"type":"reglages","cadrage":"\#(cadrage.rawValue)"}"#
    }

    /// Cloudflare coupe une WebSocket muette au bout de 100 s.
    public static let maintien = #"{"type":"ping"}"#

    /// Première ligne écrite sur la liaison TCP vers un PC : la clé partagée,
    /// sans laquelle le PC ferme la connexion.
    public static func poigneeDeMain(cle: String) -> Data {
        let objet = ["cle": cle]
        let json = (try? JSONSerialization.data(withJSONObject: objet)) ?? Data("{}".utf8)
        return json + Data([0x0A])
    }
}
