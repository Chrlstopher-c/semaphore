import Foundation

/// Ce que les comptes Claude disent du parc pris dans son ensemble.
///
/// `☠` RAISONNER EN POURCENTAGE, JAMAIS EN DOLLARS : sur abonnement, les champs
/// en dollars de l'API d'usage sont nuls (H-63/H-70). Le seul chiffre fiable est
/// l'occupation de la fenêtre.
public struct SyntheseQuotas: Sendable, Equatable {
    /// Occupation moyenne des fenêtres de 5 h, 0…1.
    ///
    /// `☠` Une moyenne, et son réserve est écrite ici : un point de fenêtre
    /// n'achète pas le même travail sur un abonnement Pro et sur un Max. Elle dit
    /// « le parc est chargé », pas « il reste exactement tant ». Le chiffre
    /// actionnable est `plusLibre`, qui décide où lancer maintenant.
    public let moyenneCinqHeures: Double
    /// Le compte le moins chargé parmi ceux qui acceptent encore du travail.
    /// `nil` quand ils sont tous rejetés — et là, plus rien ne peut partir.
    public let plusLibre: AccountApi?
    /// Comptes dont la fenêtre a rejeté. La session continue en dépassement
    /// PAYANT, elle ne s'arrête pas.
    public let satures: Int
    /// Comptes en dépassement facturé à l'instant.
    public let enDepassement: Int
    public let total: Int

    public var aucunCompte: Bool { total == 0 }

    /// Vrai quand plus aucun compte n'a de fenêtre disponible : la seule
    /// situation où lancer une équipe engage de l'argent à coup sûr.
    public var parcSature: Bool { total > 0 && plusLibre == nil }
}

extension SyntheseQuotas {

    public static func depuis(_ comptes: [AccountApi]) -> SyntheseQuotas {
        guard !comptes.isEmpty else {
            return SyntheseQuotas(
                moyenneCinqHeures: 0, plusLibre: nil, satures: 0, enDepassement: 0, total: 0
            )
        }
        let somme = comptes.reduce(0) { $0 + $1.fiveHour.util }
        let disponibles = comptes
            .filter { $0.status != .rejete }
            .sorted { $0.fiveHour.util < $1.fiveHour.util }
        return SyntheseQuotas(
            moyenneCinqHeures: Double(somme) / Double(comptes.count) / 100,
            plusLibre: disponibles.first,
            satures: comptes.filter { $0.status == .rejete }.count,
            enDepassement: comptes.filter(\.isUsingOverage).count,
            total: comptes.count
        )
    }
}
