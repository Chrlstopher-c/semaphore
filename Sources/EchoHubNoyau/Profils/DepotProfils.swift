import Foundation

/// Un profil (`backend/chat/profils.py`) : style, outils et réglages du modèle qu'une conversation peut suivre.
public struct Profil: Sendable, Decodable, Equatable, Identifiable {
    public let id: String
    public var edition: EditionProfil

    public var nom: String { edition.nom }

    public init(from decodeur: any Decoder) throws {
        id = try decodeur.container(keyedBy: Cle.self).decode(String.self, forKey: .id)
        edition = try EditionProfil(from: decodeur)
    }

    private enum Cle: String, CodingKey { case id }
}

/// Corps de création et de modification : le profil entier, sans identifiant.
public struct EditionProfil: Sendable, Codable, Equatable {
    public var nom: String
    public var style: String
    /// `nil` = tous les outils, `[]` = aucun.
    public var outils: [String]?
    public var parametres: ParametresEchantillonnage
    public var modeProjet: Bool
    public var hybride: Bool

    public init(
        nom: String = "", style: String = "", outils: [String]? = nil,
        parametres: ParametresEchantillonnage = ParametresEchantillonnage(), modeProjet: Bool = false, hybride: Bool = false
    ) {
        self.nom = nom
        self.style = style
        self.outils = outils
        self.parametres = parametres
        self.modeProjet = modeProjet
        self.hybride = hybride
    }

    private enum CodingKeys: String, CodingKey { case nom, style, outils, parametres, modeProjet, hybride }

    public init(from decodeur: any Decoder) throws {
        let c = try decodeur.container(keyedBy: CodingKeys.self)
        self.init(
            nom: try c.decode(String.self, forKey: .nom),
            style: try c.decodeIfPresent(String.self, forKey: .style) ?? "",
            outils: try c.decodeIfPresent([String].self, forKey: .outils),
            parametres: try c.decodeIfPresent(ParametresEchantillonnage.self, forKey: .parametres) ?? ParametresEchantillonnage(),
            modeProjet: try c.decodeIfPresent(Bool.self, forKey: .modeProjet) ?? false,
            hybride: try c.decodeIfPresent(Bool.self, forKey: .hybride) ?? false
        )
    }

    /// `outils` toujours écrit, `null` compris : « tous » et « inchangé » ne se confondent pas.
    public func encode(to encodeur: any Encoder) throws {
        var c = encodeur.container(keyedBy: CodingKeys.self)
        try c.encode(nom, forKey: .nom)
        try c.encode(style, forKey: .style)
        if let outils { try c.encode(outils, forKey: .outils) } else { try c.encodeNil(forKey: .outils) }
        try c.encode(parametres, forKey: .parametres)
        try c.encode(modeProjet, forKey: .modeProjet)
        try c.encode(hybride, forKey: .hybride)
    }
}

public struct DepotProfils: Sendable {
    let client: ClientEchoHub

    public init(client: ClientEchoHub) { self.client = client }

    public func lister() async throws -> [Profil] {
        try await client.lire([Profil].self, "GET", "chat/profils")
    }

    public func creer(_ edition: EditionProfil) async throws -> Profil {
        try await client.lire(Profil.self, "POST", "chat/profils", corps: try CodageJSON.encodeur().encode(edition))
    }

    public func modifier(_ id: String, _ edition: EditionProfil) async throws -> Profil {
        try await client.lire(
            Profil.self, "PATCH", "chat/profils/\(DepotProjets.encoder(id))", corps: try CodageJSON.encodeur().encode(edition)
        )
    }

    public func supprimer(_ id: String) async throws {
        try await client.executer("DELETE", "chat/profils/\(DepotProjets.encoder(id))")
    }

    public func profil(deLaConversation identifiant: String) async throws -> String? {
        try await client.lire(Liaison.self, "GET", "chat/conversations/\(identifiant)/profil").profilId
    }

    /// Lie un profil (ses valeurs remplacent les réglages de la conversation) ou détache avec `nil`.
    public func choisir(_ identifiant: String, profil: String?) async throws -> String? {
        try await client.lire(
            Liaison.self, "PATCH", "chat/conversations/\(identifiant)/profil", corps: Self.corpsLiaison(profil)
        ).profilId
    }

    static func corpsLiaison(_ profil: String?) -> Data {
        guard let profil, let texte = try? JSONEncoder().encode(profil) else { return Data("{\"profil_id\":null}".utf8) }
        return Data("{\"profil_id\":".utf8) + texte + Data("}".utf8)
    }

    private struct Liaison: Decodable { let profilId: String? }
}
