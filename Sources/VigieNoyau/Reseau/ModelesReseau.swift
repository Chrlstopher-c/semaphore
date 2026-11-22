import Foundation

// Responsabilité : les modèles de l'API du réseau côté téléphone (`/api/reseau/telephone/`) — erreur, vue de
// la charte, machines, demandes d'appairage, codes, ajouts, activité des invités. Décodage tolérant où le serveur
// peut ajouter des champs ou omettre un état.

/// Erreur du réseau : le message va à l'appli ; `statut` est le code HTTP quand le nœud a répondu.
public struct ErreurReseau: Error, LocalizedError, Equatable, Sendable {
    public let message: String
    public let statut: Int?

    public init(message: String, statut: Int? = nil) {
        self.message = message
        self.statut = statut
    }

    public var errorDescription: String? { message }
}

public enum SorteMembre: String, Sendable, CaseIterable { case serveur, pair, telephone }

/// Actions d'un chef sur la machine d'un nœud. `reveiller` part d'un nœud voisin en ligne.
public enum ActionMachine: String, Sendable, CaseIterable { case arreter, pause, reprendre, redemarrer, reveiller }

/// Ce que le chef accorde à une demande d'appairage : un membre plein (sorte) ou un invité (réglages).
public enum AccordDemande: Sendable, Equatable {
    case membre(SorteMembre)
    case invite(ReglagesInvite)
}

/// La charte telle que le téléphone la voit : reconstruite depuis le texte signé. `digne` = garde passée ET chef
/// avec sa propre identité : seule une vue digne autorise une édition ou une action.
public struct VueCharte: Sendable, Equatable {
    public let charte: CharteReseau?
    public let signee: CharteSignee?
    public let noeud: String?
    public let appareil: String
    public let chef: Bool
    public let digne: Bool
}

public struct GpuMachine: Sendable, Equatable, Decodable {
    public let nom: String
    public let utilisation: Double?
    public let memoireUtilisee: Double?
    public let memoireTotale: Double?
}

/// État d'une machine (`etat_noeud` du nœud), décodé de façon tolérante : un champ absent prend une valeur sûre.
/// Renommé depuis `EtatMachine` : ce nom est déjà pris par le parc du relais (Contrat/Parc.swift).
public struct EtatMachineReseau: Sendable, Equatable, Decodable {
    public let cpu: Double?
    public let charge: Double?
    public let memoireUtilisee: Double?
    public let memoireTotale: Double?
    public let gpu: [GpuMachine]
    public let pause: Bool
    public let voix: String
    public let dictee: String
    public let comptes: [String]
    public let compte: String?
    public let peutArreter: Bool
    public let peutRedemarrer: Bool
    public let reveilPossible: Bool

    private enum Cles: String, CodingKey {
        case cpu, charge, memoire, gpu, pause, fonctions, comptes, compte, peutArreter, peutRedemarrer, reveilPossible
    }

    private struct Memoire: Decodable {
        let utilisee: Double?
        let totale: Double?
    }

    private struct Fonctions: Decodable {
        let voix: String?
        let dictee: String?
    }

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: Cles.self)
        cpu = c.facultatif(Double.self, .cpu)
        charge = c.facultatif(Double.self, .charge)
        let memoire = c.facultatif(Memoire.self, .memoire)
        memoireUtilisee = memoire?.utilisee
        memoireTotale = memoire?.totale
        gpu = c.facultatif([GpuMachine].self, .gpu) ?? []
        pause = c.facultatif(Bool.self, .pause) ?? false
        let fonctions = c.facultatif(Fonctions.self, .fonctions)
        voix = fonctions?.voix ?? "absente"
        dictee = fonctions?.dictee ?? "absente"
        comptes = c.facultatif([String].self, .comptes) ?? []
        compte = c.facultatif(String.self, .compte)
        peutArreter = c.facultatif(Bool.self, .peutArreter) ?? false
        peutRedemarrer = c.facultatif(Bool.self, .peutRedemarrer) ?? false
        reveilPossible = c.facultatif(Bool.self, .reveilPossible) ?? false
    }
}

public struct MachineReseau: Sendable, Equatable, Identifiable, Decodable {
    public let membre: String
    public let nom: String
    public let moi: Bool
    public let enLigne: Bool
    public let etat: EtatMachineReseau?

    public var id: String { membre }

    private enum Cles: String, CodingKey { case membre, nom, moi, enLigne, etat }

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: Cles.self)
        membre = try c.decode(String.self, forKey: .membre)
        nom = try c.decode(String.self, forKey: .nom)
        moi = try c.decode(Bool.self, forKey: .moi)
        enLigne = try c.decode(Bool.self, forKey: .enLigne)
        etat = c.facultatif(EtatMachineReseau.self, .etat)
    }
}

/// Une demande d'appairage reçue par le nœud relié. `empreinte` est calculée ici, depuis l'identité : jamais lue
/// du serveur.
public struct DemandeReseau: Sendable, Equatable, Identifiable, Decodable {
    public let id: String
    public let membre: String
    public let nom: String
    public let genre: String
    public let identite: String
    public let le: String
    public var empreinte: String?

    private enum Cles: String, CodingKey { case id, membre, nom, genre, identite, le }

    public init(id: String, membre: String, nom: String, genre: String, identite: String, le: String) {
        self.id = id
        self.membre = membre
        self.nom = nom
        self.genre = genre
        self.identite = identite
        self.le = le
        empreinte = nil
    }

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: Cles.self)
        self.init(
            id: try c.decode(String.self, forKey: .id), membre: try c.decode(String.self, forKey: .membre),
            nom: try c.decode(String.self, forKey: .nom), genre: try c.decode(String.self, forKey: .genre),
            identite: try c.decode(String.self, forKey: .identite), le: try c.decode(String.self, forKey: .le))
    }
}

/// Le code à usage unique qu'un membre saisit pour s'appairer.
public struct CodeReseau: Sendable, Equatable, Decodable {
    public let code: String
    public let expireLe: String
}

/// Un ajout de machine en cours (code à usage unique, SSH via un nœud).
public struct AjoutReseau: Sendable, Equatable, Identifiable, Decodable {
    public let machine: String
    public let nom: String
    public let etape: String
    public let etat: String
    public let message: String?
    public let membre: String?
    public let concordance: String?
    public let empreinteSsh: String?
    public let empreinteDemande: String?

    public var id: String { machine }
}

public struct PartInvite: Sendable, Equatable, Decodable {
    public let consomme: Double
    public let part: Double
    public let reprise: String?
}

/// L'activité d'un invité (télémétrie agrégée) : compteurs du jour, parts de limite.
public struct ActiviteInvite: Sendable, Equatable, Decodable {
    public let actifAujourdhui: Bool
    public let derniere: String?
    public let sessionsAujourdhui: Int
    public let sessionsEnCours: Int
    public let jetonsAujourdhui: Int
    public let part5h: PartInvite?
    public let semaine: PartInvite?
}
