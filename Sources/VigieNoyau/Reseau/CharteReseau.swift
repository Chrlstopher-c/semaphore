import Foundation

// Responsabilité : la charte signée du réseau, lue par le téléphone — membres, chefs, droits, invités.
// Le JSON complet est gardé (`brut`) : une édition le réécrit sans perdre un champ inconnu.

/// Taille maximale d'une charte, en caractères UTF-16 (comme le serveur).
let TAILLE_MAX_CHARTE = 256 * 1024

public struct DroitsMembre: Sendable, Equatable {
    public var voir: Bool
    public var piloter: Bool
    public var lancer: Bool
    public var remoteControl: Bool

    public init(voir: Bool, piloter: Bool, lancer: Bool, remoteControl: Bool) {
        self.voir = voir
        self.piloter = piloter
        self.lancer = lancer
        self.remoteControl = remoteControl
    }

    public static let tous = DroitsMembre(voir: true, piloter: true, lancer: true, remoteControl: true)
    public static let aucun = DroitsMembre(voir: false, piloter: false, lancer: false, remoteControl: false)

    var valeurJSON: ValeurJSON {
        .objet([
            "voir": .booleen(voir), "piloter": .booleen(piloter), "lancer": .booleen(lancer),
            "remoteControl": .booleen(remoteControl),
        ])
    }

    static func lire(_ valeur: ValeurJSON?) throws -> DroitsMembre {
        let objet = try Lu.objet(valeur, "droits")
        return DroitsMembre(
            voir: try Lu.booleen(objet["voir"], "droits"), piloter: try Lu.booleen(objet["piloter"], "droits"),
            lancer: try Lu.booleen(objet["lancer"], "droits"),
            remoteControl: try Lu.booleen(objet["remoteControl"], "droits"))
    }
}

public struct MembreCharte: Sendable, Equatable, Identifiable {
    public let id: String
    public let nom: String
    public let sorte: SorteMembre
    public let identite: String
    public let droits: DroitsMembre
    public let compte: String?
    /// Présent pour un invité : ses réglages, et des droits de base tous à faux.
    public let invite: ReglagesInvite?

    static func lire(_ valeur: ValeurJSON) throws -> MembreCharte {
        let objet = try Lu.objet(valeur, "membre")
        guard let sorte = SorteMembre(rawValue: try Lu.texte(objet["sorte"], "sorte")) else {
            throw Lu.illisible("sorte")
        }
        let invite = try objet["invite"].map { try ReglagesInvite.lire($0) }
        return MembreCharte(
            id: try Lu.identifiant(objet["id"], "id"), nom: try Lu.nom(objet["nom"], "nom"), sorte: sorte,
            identite: try Lu.identite(objet["identite"], "identite"), droits: try DroitsMembre.lire(objet["droits"]),
            compte: try Lu.texteOuNul(objet["compte"], "compte", max: 200), invite: invite)
    }
}

/// La charte du réseau. Construite depuis son JSON (`brut`) : les champs typés en sont la lecture vérifiée.
public struct CharteReseau: Sendable, Equatable {
    public let brut: ValeurJSON
    public let reseau: String
    public let nom: String
    public let version: Int
    public let chefs: [String]
    public let membres: [MembreCharte]
    public let le: String
    public let par: String
    public let origine: String

    public init(brut: ValeurJSON) throws {
        let champs = try ChampsCharte.lire(brut)
        self.brut = brut
        reseau = champs.reseau
        nom = champs.nom
        version = champs.version
        chefs = champs.chefs
        membres = champs.membres
        le = champs.le
        par = champs.par
        origine = champs.origine
    }

    public init(texte: String) throws {
        guard texte.utf16.count <= TAILLE_MAX_CHARTE else { throw Lu.illisible("taille") }
        let brut: ValeurJSON
        do { brut = try ValeurJSON.lire(texte) } catch {
            Trace.erreur("reseau", "charte illisible : JSON", error)
            throw Lu.illisible("JSON")
        }
        try self.init(brut: brut)
    }

    public func membre(_ id: String) -> MembreCharte? { membres.first { $0.id == id } }

    public func estChef(_ id: String) -> Bool { chefs.contains(id) }

    var objetBrut: [String: ValeurJSON] {
        guard case .objet(let objet) = brut else { return [:] }
        return objet
    }

    var membresBrut: [ValeurJSON] {
        guard case .tableau(let membres)? = objetBrut["membres"] else { return [] }
        return membres
    }
}
