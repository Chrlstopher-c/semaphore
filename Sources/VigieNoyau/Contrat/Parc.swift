import Foundation

/// Une machine de travail connue du Pi (`GET /machines`).
///
/// Elle reste dans la liste quand elle est éteinte : la retirer ferait
/// disparaître de l'écran une machine sur laquelle des missions vivent.
public struct MachineApi: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let enLigne: Bool
    /// Évictions observées sur CETTE machine — doit rester à 0.
    public let supersedes: Int
}

/// Relevé matériel d'une machine (`GET /machines/metriques`).
///
/// `☠` Route SÉPARÉE de `/machines` à dessein : elle fait un aller-retour PAR
/// machine, jusqu'à Cloudflare pour le VPS. À demander, jamais à sonder en boucle.
public struct MetriquesMachineApi: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let enLigne: Bool
    /// `nil` signifie « pas pu mesurer », JAMAIS « tout à zéro ».
    public let metriques: MetriquesHote?
}

/// Ce qu'une machine sait dire d'elle-même. Chaque champ nul s'affiche « — » :
/// « pas mesuré » et « au repos » sont deux informations opposées, et c'est sur
/// ces chiffres qu'on choisit où lancer.
public struct MetriquesHote: Decodable, Sendable, Hashable {
    public let machine: String
    /// Rapport de DEUX relevés : `nil` au premier passage après démarrage.
    public let cpuPct: Int?
    public let memUtiliseeMo: Int?
    public let memTotaleMo: Int?
    public let memPct: Int?
    public let disqueUtiliseGo: Double?
    public let disqueTotalGo: Double?
    /// Lue par NOM de capteur (`k10temp`, `coretemp`, `cpu_thermal`), jamais par
    /// numéro : `thermal_zone0` rendait 16,8 °C sur un processeur à 72,75 °C.
    /// `nil` sur une machine virtualisée, qui n'a aucun capteur.
    public let tempCpuC: Int?
    public let uptimeS: Int
    public let reseauMontantKo: Double?
    public let reseauDescendantKo: Double?
    /// `nil` sur une machine sans GPU NVIDIA. Ne PAS afficher une carte à zéro :
    /// « 0 % » ferait croire à une carte inactive, pas absente.
    public let gpu: MetriquesGpu?
    public let releveA: Int
}

public struct MetriquesGpu: Decodable, Sendable, Hashable {
    public let utilPct: Int?
    public let memUtiliseeMo: Int?
    public let memTotaleMo: Int?
    public let tempC: Int?
}

/// `GET /health`. `☠` HORS ENVELOPPE : forme nue `{ ok, pcOnline }`. La décoder
/// avec le décodeur de lecture produirait un « contrat rompu » sur un serveur sain.
public struct SanteApi: Decodable, Sendable, Hashable {
    /// Le control plane répond. Distinct de `pcOnline` : l'interface doit pouvoir
    /// dire lequel des deux manque.
    public let ok: Bool
    public let pcOnline: Bool
}

/// Un modèle du catalogue (`GET /modeles`).
public struct ModeleApi: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let label: String
    /// Alias court accepté par le CLI (`opus`, `sonnet`). `nil` quand il n'y en a pas.
    public let alias: String?
    /// Tout le catalogue est sélectionnable : la disponibilité réelle dépend de
    /// l'abonnement, et le CLI la tranche à l'usage.
    public let enabled: Bool
    /// `☠` VIDE = ce modèle REFUSE le paramètre d'effort (cas de Haiku). Un
    /// niveau invalide est ignoré EN SILENCE par le SDK, jamais rejeté : le
    /// sélecteur doit donc se griser, sinon Chris croit régler quelque chose.
    public let effort: [String]
    public let effortDefaut: String?
    /// Le mode rapide n'existe que sur la famille Opus récente.
    public let fastMode: Bool
    /// DÉRIVÉ de la présence de `xhigh` dans les efforts, jamais une colonne à part.
    public let ultracode: Bool
    public let note: String
}

/// Un rappel programmé sur un fil.
///
/// `☠` Appartient à UN fil et n'en sort jamais. La CRÉATION et la rédaction de
/// la consigne n'ont volontairement pas de route : c'est l'orchestrateur qui les
/// écrit. L'écran donne la visibilité et le contrôle, pas la plume.
public struct RappelApi: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let label: String
    /// La consigne ENTIÈRE : c'est ce que l'orchestrateur recevra mot pour mot.
    /// Un libellé seul ne dit rien de ce qui sera réellement injecté.
    public let instruction: String
    /// `☠` ÉNUMÉRÉ, pas un booléen : « en pause » se reprend, « terminé » jamais.
    public let state: EtatRappelApi
    /// Échéance ABSOLUE en epoch ms, jamais un délai — un délai figé à l'instant
    /// de la réponse vieillit dès qu'il s'affiche. `nil` quand le rappel est terminé.
    public let nextAt: Int?
    /// `nil` pour un rappel unique.
    public let everyMinutes: Int?
    public let fired: Int
    public let maxFires: Int?
    public let lastFiredAt: Int?
    /// Dernier report ou échec, en clair. N'empêche jamais un tir ultérieur.
    public let lastError: String?
}
