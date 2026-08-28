import Foundation

/// Le catalogue des chemins servis par le Pi. Source unique : une URL construite
/// à la main dans un écran finit toujours par diverger de celle du serveur.
///
/// `☠` Aucune de ces routes n'est joignable sans session : `check_session` est
/// monté devant tout, y compris devant le relais du harness. Un décodeur JSON
/// qui suit une redirection recevra le HTML de `/login` en 200 — voir
/// `Route.exigeRefusDeRedirection`.
public enum Route {
    /// Préfixe du relais vers le control plane du harness.
    public static let harness = "/api/harness"

    // MARK: - Lectures du harness (enveloppe H-75)

    public static let sante = "\(harness)/health"
    public static let missions = "\(harness)/missions"
    public static func mission(_ id: String) -> String { "\(missions)/\(echapper(id))" }
    public static func sousAgent(mission: String, agent: String) -> String {
        "\(self.mission(mission))/agents/\(echapper(agent))"
    }
    public static let comptes = "\(harness)/accounts"
    public static let modeles = "\(harness)/modeles"
    public static let machines = "\(harness)/machines"
    /// `☠` Un aller-retour PAR machine, jusqu'à Cloudflare pour le VPS. À la
    /// demande, jamais en boucle.
    public static let metriquesMachines = "\(harness)/machines/metriques"
    public static let notifications = "\(harness)/notifications"
    public static let jauges = "\(harness)/orchestrator/gauges"
    public static let propositions = "\(harness)/orchestrator/propositions"
    public static let rallonges = "\(harness)/orchestrator/rallonges"
    public static let fils = "\(harness)/orchestrator/conversations"
    public static func fil(_ id: String) -> String { "\(fils)/\(echapper(id))" }
    /// `since` est le curseur rendu par la lecture précédente (`cursor`).
    public static func evenementsFil(_ id: String, depuis curseur: Int) -> String {
        "\(fil(id))/events?since=\(curseur)"
    }
    public static func rappels(fil id: String) -> String { "\(fil(id))/rappels" }
    /// `☠` La SEULE route du contrat qui rend des OCTETS et non du JSON.
    public static func pieceJointe(fil id: String, fichier: String) -> String {
        "\(fil(id))/pieces/\(echapper(fichier))"
    }

    // MARK: - Écritures du harness (forme nue `{ ok, effet, … }`)

    public static func approuverMandat(_ id: String) -> String {
        "\(propositions)/\(echapper(id))/approve"
    }
    public static func refuserMandat(_ id: String) -> String {
        "\(propositions)/\(echapper(id))/reject"
    }
    public static func accorderRallonge(_ id: String) -> String {
        "\(rallonges)/\(echapper(id))/approve"
    }
    public static func refuserRallonge(_ id: String) -> String {
        "\(rallonges)/\(echapper(id))/reject"
    }
    public static func marquerNotificationLue(_ id: String) -> String {
        "\(notifications)/\(echapper(id))/read"
    }
    public static let marquerToutesNotificationsLues = "\(notifications)/read-all"
    public static func messageFil(_ id: String) -> String { "\(fil(id))/message" }
    public static func interrompreFil(_ id: String) -> String { "\(fil(id))/interrompre" }
    public static func compacterFil(_ id: String) -> String { "\(fil(id))/compact" }
    public static func renommerFil(_ id: String) -> String { "\(fil(id))/rename" }
    public static func archiverFil(_ id: String) -> String { "\(fil(id))/archive" }
    public static func machineDuFil(_ id: String) -> String { "\(fil(id))/machine" }
    public static func autonomieDuFil(_ id: String) -> String { "\(fil(id))/autonomie" }
    /// `action` vaut `pause`, `resume` ou `delete`.
    public static func actionRappel(fil: String, rappel: String, action: String) -> String {
        "\(rappels(fil: fil))/\(echapper(rappel))/\(action)"
    }
    public static func terminerMission(_ id: String) -> String { "\(mission(id))/terminate" }
    public static func instructionMission(_ id: String) -> String { "\(mission(id))/instruction" }
    public static func interrompreMission(_ id: String) -> String { "\(mission(id))/interrupt" }
    public static func mettreEnPauseMission(_ id: String) -> String { "\(mission(id))/pause" }
    public static func reprendreMission(_ id: String) -> String { "\(mission(id))/resume" }
    public static func inspecterMission(_ id: String) -> String { "\(mission(id))/inspect" }
    public static func arbitrerInspection(_ id: String) -> String { "\(mission(id))/inspect/decision" }

    // MARK: - Routes natives de pi-web (hors enveloppe, hors relais)

    public static let statutPoste = "/api/status"
    public static let reveillerPoste = "/api/wake"
    public static let sessionsPoste = "/api/sessions"
    public static func lancerSession(_ nom: String) -> String {
        "/api/launch?session=\(echapper(nom))"
    }
    public static func tuerSession(_ nom: String) -> String {
        "/api/kill?session=\(echapper(nom))"
    }
    public static func capturerSession(_ nom: String) -> String {
        "/api/capture?session=\(echapper(nom))"
    }
    public static func envoyerAuTerminal(_ nom: String) -> String {
        "/api/send?session=\(echapper(nom))"
    }
    public static let configuration = "/api/config"
    public static let comptesClaude = "/api/claude-accounts"
    public static let basculerCompteClaude = "/api/claude-accounts/switch"
    public static let connexion = "/login"

    /// `☠` HORS PÉRIMÈTRE, décision de Chris du 2026-08-18 : l'agent
    /// conversationnel de la webapp v1 (`/api/agent/chat`, `/api/agent/usage`,
    /// `/api/agent/context-usage`) ne sera PAS porté. Vigie est le client de
    /// l'orchestrateur et du parc, pas un second chat. Ne pas rouvrir en
    /// croyant combler un oubli : c'est un retrait assumé.
    public static let agentWebappHorsPerimetre = "/api/agent/chat"

    /// `☠` HORS PÉRIMÈTRE v1, et l'omission est délibérée : `POST /api/shutdown`
    /// éteint la machine de travail sans confirmation serveur. Sur un écran tenu
    /// d'une main, le rapport bénéfice/risque est mauvais. À rouvrir seulement
    /// derrière un geste armé et Face ID.
    public static let extinctionPosteHorsPerimetre = "/api/shutdown"

    /// Encodage de segment d'URL. Le serveur `decodeURIComponent` chaque segment
    /// capturé : un identifiant non encodé casserait le routage sur un titre à
    /// espaces ou un nom de fichier accentué.
    static func echapper(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: caracteresNonReserves) ?? segment
    }

    /// Les caractères « non réservés » de la RFC 3986. Tout le reste est encodé.
    private static let caracteresNonReserves = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "-._~"))
}

extension Route {
    /// Toute réponse doit être décodée SANS suivre de redirection.
    ///
    /// `check_session` répond 303 vers `/login` sur une session absente ou
    /// périmée. URLSession suit les redirections par défaut et rendrait le HTML
    /// de la page de connexion en **200** à un décodeur JSON — donc un « contrat
    /// rompu » incompréhensible au lieu d'une demande de reconnexion.
    public static let exigeRefusDeRedirection = true

    /// Délai des LECTURES. Le relais impose déjà 5 s au harness ; on garde une
    /// marge pour le tunnel Cloudflare et rien de plus : une lecture qui traîne
    /// immobilise l'écran pendant que le miroir a déjà la réponse d'avant.
    public static let delaiLectureS: Double = 10

    /// Délai des ÉCRITURES. Le relais monte à 130 s parce qu'un tour
    /// d'orchestrateur peut mettre des dizaines de secondes à revenir. Une
    /// session HTTP séparée est nécessaire : un même délai pour les deux ferait
    /// attendre 130 s sur un simple rafraîchissement de parc.
    public static let delaiEcritureS: Double = 135
}
