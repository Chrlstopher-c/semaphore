import Foundation

/// Une sortie audio du PC dont on peut capter le son. Les noms de champs sont
/// ceux de `PROTOCOLE.md` — le PC les écrit tels quels, on ne les traduit pas.
public struct SourceAudio: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let nom: String
    /// La sortie que le PC propose par défaut.
    public let defaut: Bool

    public init(id: String, nom: String, defaut: Bool) {
        self.id = id
        self.nom = nom
        self.defaut = defaut
    }
}

/// Ce que le PC renvoie par AirPlay quand il joue lui-même vers une enceinte.
/// Purement informatif côté iPhone : le sens PC → enceinte ne passe pas par
/// notre code, `shairport-sync` s'en charge.
public struct EtatAirPlay: Sendable, Equatable, Codable {
    public let actif: Bool
    public let appareil: String

    public init(actif: Bool, appareil: String) {
        self.actif = actif
        self.appareil = appareil
    }
}

/// Le message `etat` : où en est l'émission côté PC.
public struct EtatPoste: Sendable, Equatable, Codable {
    public let emission: Bool
    /// L'identifiant de la source captée.
    public let source: String
    public let airplay: EtatAirPlay

    public init(emission: Bool, source: String, airplay: EtatAirPlay) {
        self.emission = emission
        self.source = source
        self.airplay = airplay
    }
}

/// Un PC trouvé par mDNS, avant toute connexion. `id` vient de l'enregistrement
/// TXT (16 hex) et c'est LUI la clé du jeton conservé, jamais l'adresse IP —
/// une IP change au bail DHCP suivant, et le jumelage serait à refaire.
public struct PosteTrouve: Sendable, Equatable, Identifiable {
    public let id: String
    public let nom: String
    /// Le nom de service Bonjour, tel que `NWBrowser` l'a rendu. C'est par lui
    /// qu'on rouvre une connexion, jamais par une adresse devinée.
    public let service: String

    public init(id: String, nom: String, service: String) {
        self.id = id
        self.nom = nom
        self.service = service
    }
}

/// Lit l'enregistrement TXT publié par le PC (`v`, `nom`, `id`).
///
/// `☠` Un TXT sans `id` est inexploitable : sans identifiant stable, impossible
/// de retrouver le jeton du jumelage précédent, et Chris retaperait un code à
/// chaque bail DHCP. On préfère ignorer le service que l'afficher cassé.
public enum EnregistrementTXT {
    public static let versionAttendue = "1"

    public static func lire(_ champs: [String: String], service: String) -> PosteTrouve? {
        guard champs["v"] == versionAttendue else { return nil }
        guard let identifiant = champs["id"], identifiant.count == 16,
              identifiant.allSatisfy(\.isHexDigit) else { return nil }
        let nom = champs["nom"].flatMap { $0.isEmpty ? nil : $0 } ?? service
        return PosteTrouve(id: identifiant.lowercased(), nom: nom, service: service)
    }
}
