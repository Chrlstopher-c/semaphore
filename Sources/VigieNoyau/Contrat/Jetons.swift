import Foundation

/// Un jeton de chaîne du contrat serveur dont la liste peut s'allonger sans
/// qu'on redéploie le client.
///
/// Le contrat le dit explicitement pour `TypeNotification` (« liste OUVERTE par
/// conception ») et le même risque existe partout ailleurs : une valeur ajoutée
/// côté Pi ne doit jamais faire échouer le décodage de la ligne entière. Un
/// `enum` fermé transformerait un ajout serveur en écran vide. On conserve donc
/// la chaîne TELLE QUELLE et on expose les valeurs connues en constantes.
public protocol JetonContrat: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible
where RawValue == String {
    init(rawValue: String)
}

extension JetonContrat {
    public init(from decodeur: Decoder) throws {
        self.init(rawValue: try decodeur.singleValueContainer().decode(String.self))
    }

    public func encode(to encodeur: Encoder) throws {
        var contenant = encodeur.singleValueContainer()
        try contenant.encode(rawValue)
    }

    public var description: String { rawValue }
}

/// État d'affichage d'une mission, décodé TEL QUEL.
///
/// Le serveur le calcule en croisant `etatHarness` (autorité du Pi) et `etatSdk`
/// (autorité du PC). Le recalculer ici rejouerait la panne #30 du projet : deux
/// machines à états qu'on croise dans un client n'ont aucune chance de rester
/// d'accord avec celle qui fait autorité.
public struct EtatMissionApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let requiertAction = EtatMissionApi(rawValue: "requires_action")
    public static let enCours = EtatMissionApi(rawValue: "running")
    public static let auRepos = EtatMissionApi(rawValue: "idle")
    public static let enPause = EtatMissionApi(rawValue: "paused")
    public static let echec = EtatMissionApi(rawValue: "echec")
    public static let terminee = EtatMissionApi(rawValue: "terminee")

    /// États sur lesquels le parc considère l'équipe vivante — même liste que le
    /// front (`pcview.js`), qui exclut les terminaux pour compter les équipes.
    public static let vivants: Set<EtatMissionApi> = [.requiertAction, .enCours, .auRepos, .enPause]

    public var estVivante: Bool { EtatMissionApi.vivants.contains(self) }
}

/// Nature d'un fait notifiable. Liste ouverte assumée côté serveur.
public struct TypeNotificationApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let equipeTerminee = TypeNotificationApi(rawValue: "equipe_terminee")
    public static let equipeEchouee = TypeNotificationApi(rawValue: "equipe_echouee")
}

/// Type d'un bloc du fil orchestrateur.
///
/// Le front a déjà payé l'omission d'un cas : `hBlocNode` rendait `nil` sur un
/// type inconnu et l'évènement était jeté en silence — la notification agissait
/// sur l'orchestrateur sans jamais apparaître à l'écran.
public struct TypeEvenementApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let operateur = TypeEvenementApi(rawValue: "operateur")
    public static let reflexion = TypeEvenementApi(rawValue: "reflexion")
    public static let texte = TypeEvenementApi(rawValue: "texte")
    public static let outil = TypeEvenementApi(rawValue: "outil")
    public static let resultat = TypeEvenementApi(rawValue: "resultat")
    public static let erreur = TypeEvenementApi(rawValue: "erreur")
    public static let compaction = TypeEvenementApi(rawValue: "compaction")
    /// Le contenu est l'identifiant de la proposition, pas son texte.
    public static let mandat = TypeEvenementApi(rawValue: "mandat")
    /// Un fait du parc, JAMAIS une parole de Chris (H-66).
    public static let notification = TypeEvenementApi(rawValue: "notification")
    /// Un contenu que l'orchestrateur produit lui-même — script shell/Python/Lua
    /// ou page HTML — affiché dans le fil au lieu d'être noyé dans un bloc de
    /// texte (migration 30 côté serveur). `contenu` porte le nom d'affichage,
    /// la pièce elle-même vit dans `pieces` — même descriptif qu'un message
    /// opérateur, un seul élément.
    public static let artefact = TypeEvenementApi(rawValue: "artefact")
}

/// Type d'une ligne du fil d'une mission (`vue-feed.ts`).
public struct TypeFeedApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let permission = TypeFeedApi(rawValue: "permission")
    public static let activite = TypeFeedApi(rawValue: "activity")
    public static let systeme = TypeFeedApi(rawValue: "system")
    public static let instruction = TypeFeedApi(rawValue: "instruction")
}

/// Précision sur une `activity` — absente pour un texte.
public struct NatureFeedApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let reflexion = NatureFeedApi(rawValue: "reflexion")
    public static let outil = NatureFeedApi(rawValue: "outil")
}

/// Ce qu'un mandat autorise RÉELLEMENT. H-61 exige que ce champ soit affiché au
/// même rang que le titre : c'est lui qui change la portée de ce qu'on approuve.
public struct AccesMandatApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let lecture = AccesMandatApi(rawValue: "lecture")
    public static let ecriture = AccesMandatApi(rawValue: "ecriture")

    /// Défaut SÛR, aligné sur `shared/acces-mandat.ts` : un accès absent ou
    /// inconnu se lit « lecture », jamais « écriture ».
    public var ouvreLEcriture: Bool { self == .ecriture }
}

public struct StatutPropositionApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let enAttente = StatutPropositionApi(rawValue: "en_attente")
    public static let approuvee = StatutPropositionApi(rawValue: "approuvee")
    public static let refusee = StatutPropositionApi(rawValue: "refusee")
}

public struct StatutRallongeApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let enAttente = StatutRallongeApi(rawValue: "en_attente")
    public static let accordee = StatutRallongeApi(rawValue: "accordee")
    public static let refusee = StatutRallongeApi(rawValue: "refusee")
}

public struct VerdictInspectionApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let progres = VerdictInspectionApi(rawValue: "progres")
    public static let incertain = VerdictInspectionApi(rawValue: "incertain")
    public static let boucle = VerdictInspectionApi(rawValue: "boucle")
}

public struct DecisionInspectionApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let enAttente = DecisionInspectionApi(rawValue: "en_attente")
    public static let confirme = DecisionInspectionApi(rawValue: "confirme")
    public static let decline = DecisionInspectionApi(rawValue: "decline")
}

public struct EtatRappelApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let actif = EtatRappelApi(rawValue: "actif")
    public static let enPause = EtatRappelApi(rawValue: "en_pause")
    public static let termine = EtatRappelApi(rawValue: "termine")
}

public struct StatutSousAgentApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let actif = StatutSousAgentApi(rawValue: "actif")
    public static let attente = StatutSousAgentApi(rawValue: "attente")
    public static let termine = StatutSousAgentApi(rawValue: "termine")
}

/// Statut d'une fenêtre de quota (H-63.1).
///
/// `rejected` NE COUPE PAS la session : elle continue en dépassement payant.
/// D'où `isUsingOverage`, distinct du statut — les fondre ferait afficher un
/// arrêt là où de l'argent réel est en train d'être dépensé.
public struct StatutQuotaApi: JetonContrat {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let autorise = StatutQuotaApi(rawValue: "allowed")
    public static let avertissement = StatutQuotaApi(rawValue: "allowed_warning")
    public static let rejete = StatutQuotaApi(rawValue: "rejected")
}
