import Foundation

/// La forme sous laquelle une réponse a été servie, mémorisée avec elle.
///
/// Le miroir range le corps HTTP **brut**, pas un objet décodé. Deux raisons,
/// et la seconde est décisive :
///  - les types de `Contrat/` sont `Decodable` seulement ; les rendre
///    `Encodable` obligerait à écrire un second contrat, en miroir du premier,
///    qui divergerait au premier champ ajouté côté serveur ;
///  - relire le miroir rejoue **exactement** le décodage d'origine. Un champ
///    que le décodeur refuse aujourd'hui le refusera pareil demain, au lieu de
///    ressortir d'un cache une valeur que le contrat n'accepte plus.
public enum FormeReponse: String, Codable, Sendable {
    /// Lecture du harness, enveloppée H-75 (`{ pcOnline, stale, data, message }`).
    case enveloppe
    /// Forme nue : `/health` et toutes les routes natives de `pi-web`.
    case nue
}

/// L'adresse d'une section du miroir.
///
/// `precision` porte l'identifiant quand la rubrique est paramétrée (un fil, une
/// mission, une session tmux). Sans elle, deux fils différents s'écraseraient.
public struct CleMiroir: Hashable, Sendable, Codable {
    public let rubrique: String
    public let precision: String?

    public init(_ rubrique: String, _ precision: String? = nil) {
        self.rubrique = rubrique
        self.precision = precision
    }

    /// La clé de rangement effective. Le séparateur `#` ne peut pas apparaître
    /// dans une rubrique : elles sont toutes déclarées ci-dessous.
    public var identifiant: String {
        guard let precision else { return rubrique }
        return "\(rubrique)#\(precision)"
    }
}

extension CleMiroir {
    public static let missions = CleMiroir("missions")
    public static let fils = CleMiroir("fils")
    public static let propositions = CleMiroir("propositions")
    public static let rallonges = CleMiroir("rallonges")
    public static let jauges = CleMiroir("jauges")
    public static let machines = CleMiroir("machines")
    public static let metriquesMachines = CleMiroir("metriquesMachines")
    public static let notifications = CleMiroir("notifications")
    public static let comptes = CleMiroir("comptes")
    public static let modeles = CleMiroir("modeles")
    public static let sante = CleMiroir("sante")
    public static let statutPoste = CleMiroir("statutPoste")
    public static let sessionsPoste = CleMiroir("sessionsPoste")
    public static let configPoste = CleMiroir("configPoste")
    public static let comptesClaude = CleMiroir("comptesClaude")
    public static let filigraneNotifications = CleMiroir("filigraneNotifications")

    public static func mission(_ identifiant: String) -> CleMiroir {
        CleMiroir("mission", identifiant)
    }

    public static func fil(_ identifiant: String) -> CleMiroir {
        CleMiroir("fil", identifiant)
    }

    public static func evenementsFil(_ identifiant: String) -> CleMiroir {
        CleMiroir("evenementsFil", identifiant)
    }

    public static func rappels(fil identifiant: String) -> CleMiroir {
        CleMiroir("rappels", identifiant)
    }

    public static func capture(session: String) -> CleMiroir {
        CleMiroir("capture", session)
    }
}

/// Un relevé rangé : le corps brut, sa forme, et sa date propre.
///
/// Chaque section est datée **de son propre relevé**. Un instantané daté d'un
/// seul horodatage global mentirait sur toutes les sections sauf une : le parc
/// tiré il y a trois heures s'afficherait aussi frais que le fil tiré il y a
/// quatre secondes.
public struct SectionMiroir: Codable, Sendable {
    public let corps: Data
    public let forme: FormeReponse
    public let releveA: Date
    /// Le PC de travail répondait-il lors de ce relevé ?
    public let pcEnLigne: Bool

    public init(corps: Data, forme: FormeReponse, releveA: Date, pcEnLigne: Bool) {
        self.corps = corps
        self.forme = forme
        self.releveA = releveA
        self.pcEnLigne = pcEnLigne
    }

    public var poids: Int { corps.count }
}

/// Une donnée sortie du miroir : la valeur ET sa date. Les deux ensemble, jamais
/// l'une sans l'autre — afficher une donnée du miroir sans dire son âge est le
/// seul moyen de transformer un avantage en mensonge.
public struct DonneeMiroir<Charge: Decodable & Sendable>: Sendable {
    public let valeur: Charge
    public let releveA: Date
    public let pcEnLigne: Bool

    public init(valeur: Charge, releveA: Date, pcEnLigne: Bool) {
        self.valeur = valeur
        self.releveA = releveA
        self.pcEnLigne = pcEnLigne
    }
}

/// L'état local persistant de Vigie : ce qu'elle sait quand elle s'ouvre, avant
/// la moindre requête.
public struct Instantane: Codable, Sendable {
    /// Incrémenter invalide tout le fichier au prochain lancement. À faire
    /// seulement si la forme du fichier change — jamais pour un champ d'API.
    public static let versionCourante = 1

    /// Au-delà, une section n'est pas rangée. Un fil de 4 Mo mettrait le miroir
    /// à genoux pour un gain nul : ce qu'on veut au démarrage, c'est la liste,
    /// pas dix mille événements.
    public static let poidsMaxSection = 1_024 * 1_024
    /// Éviction par ancienneté au-delà de ce nombre de sections.
    public static let sectionsMax = 40

    public private(set) var version: Int
    private var sections: [String: SectionMiroir]

    public init() {
        version = Self.versionCourante
        sections = [:]
    }

    public var rubriquesConnues: Int { sections.count }

    public func section(_ cle: CleMiroir) -> SectionMiroir? {
        sections[cle.identifiant]
    }

    public func releveA(_ cle: CleMiroir) -> Date? {
        sections[cle.identifiant]?.releveA
    }

    /// Relit une section en rejouant son décodage d'origine.
    /// `nil` = jamais relevée, ou corps devenu illisible pour le contrat courant.
    public func lire<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        _ cle: CleMiroir
    ) -> DonneeMiroir<Charge>? {
        guard let section = sections[cle.identifiant] else { return nil }
        guard let valeur = decoder(type, section) else { return nil }
        return DonneeMiroir(valeur: valeur, releveA: section.releveA, pcEnLigne: section.pcEnLigne)
    }

    private func decoder<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        _ section: SectionMiroir
    ) -> Charge? {
        switch section.forme {
        case .enveloppe:
            let relecture = DecodeurContrat.lecture(type, statut: 200, corps: section.corps)
            if let erreur = relecture.erreur {
                Trace.erreur("miroir", "section illisible (\(type)) : \(erreur.message)")
            }
            return relecture.charge
        case .nue:
            switch DecodeurContrat.nu(type, statut: 200, corps: section.corps) {
            case .success(let charge):
                return charge
            case .failure(let erreur):
                Trace.erreur("miroir", "section nue illisible (\(type)) : \(erreur.message)")
                return nil
            }
        }
    }

    /// Range un relevé. Un corps trop lourd est refusé, pas tronqué : une
    /// troncature produirait un JSON invalide rangé comme s'il était bon.
    public mutating func deposer(
        _ cle: CleMiroir,
        corps: Data,
        forme: FormeReponse,
        pcEnLigne: Bool,
        releveA: Date = Date()
    ) {
        guard corps.count <= Self.poidsMaxSection else {
            Trace.detail("miroir", "section \(cle.identifiant) écartée : \(corps.count) octets")
            return
        }
        sections[cle.identifiant] = SectionMiroir(
            corps: corps, forme: forme, releveA: releveA, pcEnLigne: pcEnLigne
        )
        elaguer()
    }

    public mutating func oublier(_ cle: CleMiroir) {
        sections.removeValue(forKey: cle.identifiant)
    }

    public mutating func vider() {
        sections.removeAll()
    }

    /// Éviction des sections les plus anciennes. Le miroir est un confort de
    /// démarrage, pas une archive : rien ne justifie qu'il croisse sans fin.
    private mutating func elaguer() {
        guard sections.count > Self.sectionsMax else { return }
        let gardees = sections
            .sorted { $0.value.releveA > $1.value.releveA }
            .prefix(Self.sectionsMax)
        sections = Dictionary(uniqueKeysWithValues: gardees.map { ($0.key, $0.value) })
    }
}
