import Foundation

/// Déduplication des demandes EN ATTENTE (mandats, rallonges) entre deux relevés.
///
/// `☠` Règle OPPOSÉE à celle des notifications, et c'est délibéré. Un fait du
/// harness est historique : le premier relevé après installation n'en sonne
/// AUCUN, sinon cinquante jours d'histoire tombent d'un coup. Une demande en
/// attente, elle, est un présent actionnable : trois mandats trouvés au premier
/// lancement méritent trois alertes, parce qu'ils attendent toujours.
///
/// La mémoire se borne toute seule : un identifiant disparu de la liste des
/// demandes en attente a été tranché, on l'oublie. Rien à élaguer par l'âge.
public struct SuiviDecisions: Codable, Sendable, Equatable {
    private var vus: Set<String>

    public init() {
        vus = []
    }

    /// Les identifiants jamais annoncés, dans l'ordre reçu. Effet de bord : les
    /// identifiants absents du lot sont oubliés.
    public mutating func nouveaux(_ identifiants: [String]) -> [String] {
        let presents = Set(identifiants)
        let inedits = identifiants.filter { !vus.contains($0) }
        // L'intersection AVANT l'union : ce qui n'est plus en attente sort de la
        // mémoire, ce qui vient d'arriver y entre.
        vus = vus.intersection(presents).union(presents)
        return inedits
    }

    public func dejaVu(_ identifiant: String) -> Bool {
        vus.contains(identifiant)
    }

    public var taille: Int { vus.count }
}

/// Ce que le veilleur retient d'un relevé à l'autre, en un seul objet
/// sérialisable — un seul enregistrement, donc un seul risque de désynchronisation.
///
/// `☠` Le décodage est TOLÉRANT À L'ABSENCE de chaque champ, et il doit le
/// rester : la mémoire persiste dans `UserDefaults` d'une version à l'autre.
/// Avec l'init synthétisé, ajouter un champ rendrait illisible la mémoire écrite
/// par la version précédente — donc, au premier lancement suivant une mise à
/// jour, re-sonnerait tout ce qui est en attente et rejouerait un filigrane
/// vierge. Un champ neuf vaut « rien de connu », jamais « mémoire corrompue ».
public struct MemoireVeille: Codable, Sendable, Equatable {
    public var faits: FiligraneNotifications
    public var mandats: SuiviDecisions
    public var rallonges: SuiviDecisions
    /// Les inspections qui attendent un arbitrage humain. Dédupliquées comme les
    /// mandats : ce sont des demandes en attente, pas des faits historiques.
    public var arbitrages: SuiviDecisions
    /// Les fils quittés en pleine génération — voir `AttenteFils`.
    public var filsAttendus: AttenteFils

    public init() {
        faits = FiligraneNotifications()
        mandats = SuiviDecisions()
        rallonges = SuiviDecisions()
        arbitrages = SuiviDecisions()
        filsAttendus = AttenteFils()
    }

    public init(from decodeur: Decoder) throws {
        let bac = try decodeur.container(keyedBy: CodingKeys.self)
        faits = try bac.decodeIfPresent(FiligraneNotifications.self, forKey: .faits)
            ?? FiligraneNotifications()
        mandats = try bac.decodeIfPresent(SuiviDecisions.self, forKey: .mandats) ?? SuiviDecisions()
        rallonges = try bac.decodeIfPresent(SuiviDecisions.self, forKey: .rallonges)
            ?? SuiviDecisions()
        arbitrages = try bac.decodeIfPresent(SuiviDecisions.self, forKey: .arbitrages)
            ?? SuiviDecisions()
        filsAttendus = try bac.decodeIfPresent(AttenteFils.self, forKey: .filsAttendus)
            ?? AttenteFils()
    }
}
