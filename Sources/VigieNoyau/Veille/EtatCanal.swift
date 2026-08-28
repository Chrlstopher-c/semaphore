import Foundation

/// Une alerte réellement sonnée, gardée pour l'écran du canal.
public struct EchoAlerte: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let instant: Date
    public let genre: GenreAlerte
    public let titre: String

    public init(id: String, instant: Date, genre: GenreAlerte, titre: String) {
        self.id = id
        self.instant = instant
        self.genre = genre
        self.titre = titre
    }
}

/// D'où vient un relevé. `☠` Distinction capitale pour l'écran du canal : un
/// réveil de fond RÉELLEMENT servi par iOS est une information rare et précieuse,
/// une intention de réveil n'en est pas une. La SPA n'avait rien de tel et le
/// canal ne pouvait donc pas être diagnostiqué.
public enum OrigineReleve: String, Codable, Sendable {
    case premierPlan
    case reveilDeFond
    case veilleAudio
    case veilleLocalisation
    case ouverture

    public var libelle: String {
        switch self {
        case .premierPlan: return "premier plan"
        case .reveilDeFond: return "réveil de fond"
        case .veilleAudio: return "veille audio"
        case .veilleLocalisation: return "veille par localisation"
        case .ouverture: return "ouverture de l'app"
        }
    }
}

/// L'état du canal d'alerte, persisté. C'est le seul endroit qui sache si la
/// chaîne fonctionne — et il doit le dire même quand la réponse est « non ».
public struct EtatCanal: Codable, Sendable, Equatable {
    /// Dernier contact RÉUSSI avec le Pi, toutes origines confondues. Sert de
    /// point zéro à l'alarme de silence.
    public var dernierContact: Date?
    public var derniereOrigine: OrigineReleve?
    /// `☠` Dernier réveil de fond RÉELLEMENT exécuté par iOS, pas la dernière
    /// demande de réveil. Les deux se ressemblent dans le code et n'ont rien à
    /// voir dans la réalité : iOS accorde ces réveils quand il veut, ou jamais.
    public var dernierReveilReel: Date?
    public var reveilsReels: Int
    /// La replanification a-t-elle été acceptée au dernier passage ?
    public var reveilReplanifie: Bool
    /// Le gestionnaire de tâche a-t-il pu être enregistré au lancement ?
    /// Faux ⇒ aucun réveil de fond n'arrivera jamais, et il faut le dire.
    public var reveilEnregistre: Bool
    /// Réponse du système à la demande d'autorisation, en clair.
    public var autorisation: String
    public var audioActif: Bool
    public var audioInterruptions: Int
    public var audioReprises: Int
    public var audioIncident: String?
    /// Le canal numéro deux — le relais par localisation, qui tient l'app en vie
    /// pendant qu'une autre app détient l'audio en exclusif.
    ///
    /// `☠` Optionnels, et c'est délibéré : cet état est persisté dans
    /// `UserDefaults`, et le décodage synthétisé de Swift ÉCHOUE sur une clé
    /// absente même quand la propriété a une valeur par défaut. Non optionnels,
    /// ces trois champs feraient repartir de zéro tout l'historique du canal
    /// enregistré avant leur ajout.
    public var localisationActive: Bool?
    public var localisationReleves: Int?
    public var localisationStatut: String?
    /// Alarmes de silence actuellement armées, par échéance.
    public var alarmesArmees: [Date]
    public var expirationSignature: Date?
    /// Des faits ont quitté la fenêtre serveur sans avoir été vus.
    public var rattrapageIncomplet: Bool
    /// Le motif du dernier échec de relevé, ou `nil` si le dernier tour a abouti.
    /// `☠` Un tour raté ne doit PAS repousser l'alarme de silence : sans ce
    /// champ, une panne de tunnel réarmerait les alarmes à chaque tentative et
    /// l'alarme ne sonnerait jamais, alors même que plus rien n'est su.
    public var derniereErreurTransport: String?
    public var faitsSonnes: Int
    /// Les vingt dernières alertes réellement posées, du plus récent au plus ancien.
    public var derniers: [EchoAlerte]

    static let journalMax = 20

    public init() {
        reveilsReels = 0
        reveilReplanifie = false
        reveilEnregistre = false
        autorisation = "jamais demandée"
        audioActif = false
        audioInterruptions = 0
        audioReprises = 0
        alarmesArmees = []
        rattrapageIncomplet = false
        faitsSonnes = 0
        derniers = []
    }

    public mutating func noterContact(_ instant: Date, origine: OrigineReleve) {
        dernierContact = instant
        derniereOrigine = origine
        if origine == .reveilDeFond {
            dernierReveilReel = instant
            reveilsReels += 1
        }
    }

    public mutating func noterAlerte(_ projet: ProjetNotification, instant: Date = Date()) {
        faitsSonnes += 1
        derniers.insert(
            EchoAlerte(
                id: "\(projet.identifiant)@\(Int(instant.timeIntervalSince1970))",
                instant: instant,
                genre: projet.genre,
                titre: projet.titre
            ),
            at: 0
        )
        if derniers.count > Self.journalMax { derniers.removeLast(derniers.count - Self.journalMax) }
    }

    /// Le canal numéro deux tient-il la main en ce moment ?
    public var localisationTient: Bool { localisationActive == true }

    /// Le canal tient-il debout ? Trois conditions, et l'écran doit montrer
    /// laquelle manque plutôt qu'un verdict global opaque.
    ///
    /// `☠` `audioActif || localisationTient`, jamais `audioActif` seul : quand
    /// une autre app prend l'audio — un lecteur de musique, typiquement — le
    /// canal numéro un tombe et le relais de localisation prend le sien. Exiger
    /// l'audio afficherait « canal rompu » pendant toute une écoute, alors que
    /// la veille tourne.
    public var complet: Bool {
        autorisationAccordee && (audioActif || localisationTient) && dernierContact != nil
    }

    public var autorisationAccordee: Bool { autorisation == "accordée" }
}
