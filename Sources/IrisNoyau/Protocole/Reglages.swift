/// L'objectif filmant. L'iPhone XS en a trois : grand-angle et téléobjectif au
/// dos, grand-angle en façade.
public enum Objectif: String, CaseIterable, Sendable, Codable {
    case arriere, tele, avant

    public var libelle: String {
        switch self {
        case .arriere: return "Dos"
        case .tele: return "Télé ×2"
        case .avant: return "Façade"
        }
    }
}

/// La définition envoyée. Le débit est celui d'un réseau local : l'encodeur
/// matériel tient 1080p30 à 8 Mb/s sans chauffer l'A12.
public enum Qualite: String, CaseIterable, Sendable, Codable {
    case hd720, hd1080

    public var libelle: String { self == .hd720 ? "720p" : "1080p" }
    public var debit: Int { self == .hd720 ? 4_000_000 : 8_000_000 }
}

/// Comment le PC range l'image dans sa webcam 16:9 : bandes noires ou recadrage.
public enum Cadrage: String, CaseIterable, Sendable, Codable {
    case adapter, remplir

    public var libelle: String { self == .adapter ? "Entière" : "Remplie" }
}

/// Une adresse `a.b.c.d:port` annoncée par un PC.
public struct AdressePoste: Sendable, Equatable {
    public let hote: String
    public let port: UInt16

    public init?(_ texte: String) {
        let morceaux = texte.split(separator: ":")
        guard morceaux.count == 2, let port = UInt16(morceaux[1]), port > 0 else { return nil }
        let octets = morceaux[0].split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4, octets.allSatisfy({ UInt8($0) != nil }) else { return nil }
        self.hote = String(morceaux[0])
        self.port = port
    }
}
