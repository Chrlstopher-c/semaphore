import Foundation

/// Un plan qui a réellement chargé un modèle (`GET inference/plans-eprouves`) : « comme la dernière fois ».
public struct PlanEprouve: Sendable, Equatable, Identifiable {
    public var id: String { identifiant }
    public let identifiant: String
    public let moteur: String
    public let contexte: Int?
    public let typeKvCache: String?
    public let modeEager: Bool

    /// « 64 k · q8_0 · graphes » — la ligne du web (`ChargementEprouve.tsx`).
    public var resume: String {
        let fenetre = contexte.map { $0 >= 1024 ? "\($0 / 1024) k" : "\($0)" } ?? "contexte par défaut"
        return [moteur, fenetre, typeKvCache ?? "cache par défaut", modeEager ? "sans graphes" : "graphes"]
            .joined(separator: " · ")
    }

    static func lire(_ entree: ValeurJSON) -> PlanEprouve? {
        guard let identifiant = entree["identifiant"]?.texteOuNil, let plan = entree["plan"] else { return nil }
        return PlanEprouve(
            identifiant: identifiant, moteur: plan["moteur"]?.texteOuNil ?? "?", contexte: plan["contexte"]?.entierOuNil,
            typeKvCache: plan["type_kv_cache"]?.texteOuNil, modeEager: plan["mode_eager"]?.booleenOuNil ?? false
        )
    }
}

extension DepotModeles {
    /// Plan relu OPAQUE (clés du plan intactes), résumé pour l'écran.
    public func plansEprouves() async throws -> [PlanEprouve] {
        (try await client.lireOpaque("GET", "inference/plans-eprouves").listeOuNil ?? []).compactMap(PlanEprouve.lire)
    }

    /// Recharge le modèle exactement comme la dernière fois où il a tenu.
    public func chargerPlanEprouve(_ identifiant: String) async throws -> StatutInference {
        try await client.lire(StatutInference.self, "POST", "inference/plans-eprouves/\(identifiant)/charger")
    }
}

/// Le serveur Strata de l'hôte (`GET inference/strata`) : joignable, modèle servi, contexte.
public struct SondeStrata: Sendable, Decodable, Equatable {
    public let joignable: Bool
    public let charge: Bool
    public let modele: String?
    public let contexte: Int?
    /// Ce qu'il faut faire quand il ne répond pas.
    public let detail: String?
}

extension DepotModeles {
    public func sonderStrata() async throws -> SondeStrata {
        try await client.lire(SondeStrata.self, "GET", "inference/strata")
    }

    /// Charge le modèle de Strata à la place du modèle actif.
    public func chargerStrata() async throws -> StatutInference {
        try await client.lire(StatutInference.self, "POST", "inference/strata/charger")
    }
}
