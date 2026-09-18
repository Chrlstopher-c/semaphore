import Foundation

/// Ce que le téléphone émet sur le canal de contrôle (WebSocket, TCP 7651).
///
/// `☠` Union taguée par `type`, exactement comme le fait le monde Saily avec son
/// serveur : un `enum` Swift à valeurs associées ne produit PAS spontanément
/// `{"type": "...", ...}`, et le PC ne lit que cette forme. L'encodage est donc
/// écrit à la main, et les noms de `type` sont ceux de `PROTOCOLE.md` au
/// caractère près — un point de moins et le PC ignore le message en silence.
public enum MessageTelephone: Sendable, Equatable {
    case jumelageDemande(appareil: String)
    case jumelageCode(code: String)
    case bonjour(jeton: String)
    /// Le port UDP sur lequel le téléphone écoute déjà quand il l'annonce.
    case fluxDemarrer(port: UInt16)
    case fluxArreter
    case sourceChoisir(id: String)
    case battement

    private enum Cle: String, CodingKey {
        case type, appareil, code, jeton, port, id
    }
}

extension MessageTelephone: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var bac = encoder.container(keyedBy: Cle.self)
        switch self {
        case let .jumelageDemande(appareil):
            try bac.encode("jumelage.demande", forKey: .type)
            try bac.encode(appareil, forKey: .appareil)
        case let .jumelageCode(code):
            try bac.encode("jumelage.code", forKey: .type)
            try bac.encode(code, forKey: .code)
        case let .bonjour(jeton):
            try bac.encode("bonjour", forKey: .type)
            try bac.encode(jeton, forKey: .jeton)
        case let .fluxDemarrer(port):
            try bac.encode("flux.demarrer", forKey: .type)
            try bac.encode(port, forKey: .port)
        case .fluxArreter:
            try bac.encode("flux.arreter", forKey: .type)
        case let .sourceChoisir(id):
            try bac.encode("source.choisir", forKey: .type)
            try bac.encode(id, forKey: .id)
        case .battement:
            try bac.encode("battement", forKey: .type)
        }
    }

    /// Le texte JSON à poser sur le socket.
    public func texte() throws -> String {
        let donnees = try JSONEncoder().encode(self)
        guard let texte = String(data: donnees, encoding: .utf8) else {
            throw ErreurDuplex.reponseIllisible("message non encodable")
        }
        return texte
    }
}

/// Ce que le PC pousse vers le téléphone.
public enum MessagePoste: Sendable, Equatable {
    /// Le PC affiche un code à six chiffres à l'écran ; il vit 120 s.
    case jumelageAttente
    case jumelageAccepte(jeton: String)
    case jumelageRefuse(raison: String)
    case bienvenue(nom: String, sources: [SourceAudio])
    case etat(EtatPoste)
    case battement

    private enum Cle: String, CodingKey {
        case type, jeton, raison, nom, sources, emission, source, airplay
    }

    /// `☠` Un `type` inconnu n'est pas une panne : le PC peut gagner un message
    /// qu'une vieille IPA sideloadée ne connaît pas, et l'app de Chris peut
    /// rester une semaine en retard. On rend `nil`, l'appelant ignore — plutôt
    /// que de faire tomber toute la réception sur un mot en trop.
    public static func decoder(_ donnees: Data) -> MessagePoste? {
        try? JSONDecoder().decode(MessagePoste.self, from: donnees)
    }

    public static func decoder(texte: String) -> MessagePoste? {
        decoder(Data(texte.utf8))
    }
}

extension MessagePoste: Decodable {
    public init(from decoder: any Decoder) throws {
        let bac = try decoder.container(keyedBy: Cle.self)
        let type = try bac.decode(String.self, forKey: .type)
        switch type {
        case "jumelage.attente":
            self = .jumelageAttente
        case "jumelage.accepte":
            self = .jumelageAccepte(jeton: try bac.decode(String.self, forKey: .jeton))
        case "jumelage.refuse":
            self = .jumelageRefuse(raison: try bac.decode(String.self, forKey: .raison))
        case "bienvenue":
            self = .bienvenue(
                nom: try bac.decode(String.self, forKey: .nom),
                sources: try bac.decodeIfPresent([SourceAudio].self, forKey: .sources) ?? []
            )
        case "etat":
            self = .etat(EtatPoste(
                emission: try bac.decode(Bool.self, forKey: .emission),
                source: try bac.decode(String.self, forKey: .source),
                airplay: try bac.decode(EtatAirPlay.self, forKey: .airplay)
            ))
        case "battement":
            self = .battement
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: bac,
                debugDescription: "Type de message inconnu du PC : « \(type) »"
            )
        }
    }
}

/// Les constantes de cadence du canal de contrôle, tirées du protocole.
public enum Cadence {
    /// Un battement toutes les 5 s, dans les deux sens.
    public static let battementSecondes: Double = 5
    /// Sans battement pendant 15 s, le PC cesse d'émettre — donc le téléphone
    /// considère la liaison morte au même seuil, et ne laisse pas Chris devant
    /// un bouton « en écoute » muet.
    public static let silenceToleredSecondes: Double = 15
    /// Le canal de contrôle.
    public static let portControle: UInt16 = 7651
    /// Le service publié par le PC.
    public static let service = "_duplex._tcp"
    /// Durée de vie du code affiché par le PC.
    public static let codeSecondes: Double = 120
    /// Longueur du code de jumelage.
    public static let longueurCode = 6
}
