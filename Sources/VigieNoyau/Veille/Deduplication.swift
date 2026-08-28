import Foundation

/// Ce qu'un relevé de notifications apprend au veilleur.
public struct ReleveNotifications: Sendable, Equatable {
    /// Les faits jamais vus, du plus ancien au plus récent — l'ordre dans lequel
    /// il faut les sonner.
    public let nouvelles: [NotificationApi]
    /// `true` quand le lot était plein ET commençait après le filigrane : des
    /// faits ont quitté la fenêtre serveur sans jamais être vus. À DIRE à
    /// l'écran — un rattrapage silencieusement incomplet est pire qu'absent.
    public let rattrapageIncomplet: Bool
}

/// Déduplication des notifications entre deux relevés.
///
/// `☠` UN FILIGRANE SCALAIRE SUR L'IDENTIFIANT NE MARCHE PAS. Le control plane
/// crée les notifications avec `randomUUID()` : un UUID v4 n'est pas ordonné,
/// « le dernier id vu » ne définit aucun « après ». Un tel filigrane rate ou
/// double des alertes, silencieusement.
///
/// La parade est double, et les deux moitiés sont nécessaires :
///  - un filigrane sur `createdAt`, qui EST ordonné, pour borner la mémoire ;
///  - un ensemble persistant des identifiants déjà vus, parce que deux faits
///    peuvent naître dans la même milliseconde et qu'un filigrane temporel seul
///    en perdrait un.
///
/// `☠` Aggravant, et c'est pourquoi `rattrapageIncomplet` existe :
/// `GET /notifications` rend une liste plafonnée à 50 SANS curseur `since`. Deux
/// jours sans ouvrir Vigie et les plus anciennes ont quitté la fenêtre. Ce n'est
/// pas un coût de bande passante, c'est un problème de justesse.
public struct FiligraneNotifications: Codable, Sendable, Equatable {
    /// Le `createdAt` le plus récent jamais observé. Borne l'oubli, rien d'autre.
    public private(set) var filigrane: Int
    /// A-t-on déjà vu au moins un relevé ? Voir `retenir`.
    public private(set) var amorce: Bool
    /// `id` → `createdAt`, pour pouvoir oublier les plus vieux sans oublier les
    /// récents. Un `Set` nu grossirait sans fin.
    private var vus: [String: Int]

    /// Au-delà, un fait est considéré définitivement sorti de la fenêtre serveur
    /// (plafonnée à 50) : le revoir serait une anomalie, pas un doublon.
    static let retentionMs = 7 * 24 * 60 * 60 * 1000
    /// Garde-fou de taille, indépendant du temps : une rafale d'échecs pourrait
    /// produire des milliers de lignes en une journée.
    static let plafondIdentifiants = 400

    public init() {
        filigrane = 0
        amorce = false
        vus = [:]
    }

    /// Trie un relevé : ce qui est nouveau, et si du passé a été perdu.
    ///
    /// `☠` Le PREMIER relevé n'émet rien. À la première ouverture après
    /// installation, la fenêtre serveur contient jusqu'à 50 faits vieux de
    /// plusieurs jours : les sonner d'un coup ferait couper les notifications en
    /// une soirée, après quoi plus rien ne serait su du tout.
    public mutating func retenir(_ lot: ListeNotificationsApi) -> ReleveNotifications {
        let ordonnees = lot.notifications.sorted { $0.createdAt < $1.createdAt }
        let manque = detecterTrou(ordonnees, lotPlein: lot.notifications.count >= ListeNotificationsApi.plafondServeur)
        let nouvelles = amorce ? ordonnees.filter { vus[$0.id] == nil } : []
        for notification in ordonnees { vus[notification.id] = notification.createdAt }
        filigrane = max(filigrane, ordonnees.last?.createdAt ?? filigrane)
        amorce = true
        elaguer()
        return ReleveNotifications(nouvelles: nouvelles, rattrapageIncomplet: manque)
    }

    /// Le lot est plein ET son plus ancien élément est postérieur au filigrane :
    /// tout ce qui vivait entre les deux a été tronqué par le plafond serveur.
    private func detecterTrou(_ ordonnees: [NotificationApi], lotPlein: Bool) -> Bool {
        guard amorce, lotPlein, let plusAncien = ordonnees.first else { return false }
        return plusAncien.createdAt > filigrane
    }

    /// Oubli borné : d'abord par l'âge, puis par le nombre.
    private mutating func elaguer() {
        let plancher = filigrane - Self.retentionMs
        vus = vus.filter { $0.value >= plancher }
        guard vus.count > Self.plafondIdentifiants else { return }
        let gardes = vus.sorted { $0.value > $1.value }.prefix(Self.plafondIdentifiants)
        vus = Dictionary(uniqueKeysWithValues: gardes.map { ($0.key, $0.value) })
    }

    /// Ce fait a-t-il déjà été signalé ? Utile pour ne pas re-sonner au
    /// rattrapage d'ouverture ce qui l'a déjà été en arrière-plan.
    public func dejaVue(_ identifiant: String) -> Bool {
        vus[identifiant] != nil
    }

    /// Nombre d'identifiants retenus — pour le journal, pas pour l'écran.
    public var taille: Int { vus.count }
}
