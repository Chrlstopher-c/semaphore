import Foundation

/// Un mandat proposé par l'orchestrateur, en attente d'autorisation humaine (H-61).
///
/// `☠` SERVIE BRUTE. `GET /orchestrator/propositions` rend `registre.propositions
/// .enAttente()` SANS passer par une vue de traduction — contrairement à toutes
/// les autres routes. Les noms de champs sont donc ceux du DOMAINE (français,
/// `creeA`, `majA`), pas ceux de l'interface. Le port TypeScript en déclare un
/// sous-ensemble ; c'est l'objet complet qui part sur le fil.
public struct PropositionApi: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    /// Fil d'où vient la demande. `nil` ⇒ mandat-cadre, sans fil à rouvrir.
    public let conversationId: String?
    public let projet: String
    public let objectif: String
    public let critereArret: String?
    /// Cadre de travail en clair, pour le lead. DESCRIPTIF — ne porte aucun droit.
    public let perimetre: String
    /// `☠` Le droit RÉEL, à afficher au même rang que le titre (H-61 : une
    /// autorisation éclairée). `perimetre` n'a jamais rien verrouillé : une
    /// équipe annoncée « lecture seule » recevait les mêmes outils qu'une équipe
    /// de modification tant que ce champ n'existait pas.
    public let acces: AccesMandatApi
    public let budgetMaxUsd: Double
    /// `nil` ⇒ le défaut du dispatch.
    public let modele: String?
    public let effort: String?
    public let statut: StatutPropositionApi
    /// Renseigné une fois le mandat approuvé : l'équipe créée.
    public let missionId: String?
    public let detail: String?
    public let creeA: Int
    public let majA: Int
}

/// Une demande d'ÉLARGIR l'autonomie d'un fil.
///
/// `☠` Ce n'est PAS un mandat. L'accorder n'ouvre aucun worker : ça applique un
/// réglage au fil qui l'a demandé. Les deux circuits gardent leurs libellés et
/// leurs verdicts séparés pour qu'un geste ne puisse jamais être pris pour l'autre.
public struct RallongeApi: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let conversationId: String
    /// `nil` ⇒ la demande ne porte QUE sur la plage. Ne rien afficher côté
    /// plafond dans ce cas : un « 0 » ou un « hérité » fabriqué laisserait croire
    /// à un réglage demandé.
    public let plafondDemande: ReglagePlafondApi?
    /// Plage demandée, en epoch ms. `nil` ⇒ la demande ne touche pas la fenêtre.
    public let fenetreDebut: Int?
    public let fenetreFin: Int?
    public let fenetreObjectif: String?
    public let motif: String
    public let statut: StatutRallongeApi
    public let detail: String?
    public let creeA: Int

    /// Les deux volets sont INDÉPENDANTS et au moins un est présent. Ce qui est
    /// demandé change le titre de la carte : lâcher la main jusqu'à une heure
    /// donnée et relever un nombre d'équipes sans clic n'engagent pas la même chose.
    public var porteUneFenetre: Bool { fenetreFin != nil }
    public var porteUnPlafond: Bool { plafondDemande != nil }
}

/// Dernier verdict d'inspection (H-68) et ce que l'opérateur en a fait.
///
/// Une seule forme, partagée par la lecture (`MissionApi.inspection`) et par les
/// routes d'écriture (`AccuseEcriture.inspection`). Elles avaient chacune la
/// leur — `verdict` contre `lastVerdict` — et l'écran affichait « undefined » :
/// le verdict était juste, il se perdait entre deux noms.
public struct InspectionApi: Decodable, Sendable, Hashable {
    public let lastVerdict: VerdictInspectionApi?
    public let lastAt: Int?
    public let motif: String?
    /// `decline` = « j'ai vu et je poursuis en connaissance de cause », ce qui
    /// n'est pas « je n'ai jamais regardé ». Deux situations opposées face à une
    /// équipe qui part en boucle.
    public let decision: DecisionInspectionApi?
    /// Dérivé par le serveur — ne pas le recalculer : il encode la règle
    /// « seul un `boucle` ouvre une décision », qui vit là-bas.
    public let attendArbitrage: Bool
    public let libelle: String?
}

/// Jauges de la session orchestrateur (`GET /orchestrator/gauges`).
public struct JaugesApi: Decodable, Sendable, Hashable {
    /// `nil` = session inactive ou pas encore de mesure. L'ancienne interface
    /// affichait « 23 % » codé en dur, ce qui mentait.
    public let contextPct: Int?
    public let active: Bool
}
