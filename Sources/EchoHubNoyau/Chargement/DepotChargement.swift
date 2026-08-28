import Foundation

/// Le pilotage du chargement : planifier, dégrader, appliquer, relire.
///
/// Deux règles portées ici et pas seulement par le serveur :
///
/// 1. **`charger` repose le plan DÉJÀ affiché.** Replanifier au moment du
///    chargement produirait un autre plan — la VRAM libre a pu changer — et
///    Chris obtiendrait autre chose que ce qu'il a validé.
/// 2. **Après un échec, on dégrade ; on ne relance jamais le même plan en
///    montant un paramètre.** C'était l'escalade de la v1 : contexte 55k → 131k
///    après un échec de VRAM.
///
/// `☠` Tout ce qui touche un plan passe par `lireOpaque`, jamais par le contrat
/// typé : `convertFromSnakeCase` abîmerait les clés du plan sans erreur visible.
extension DepotModeles {

    /// Fait calculer un plan par le PC. Rend la réponse ENTIÈRE — plan,
    /// justifications, avertissements — parce que l'écran affiche les trois et
    /// que `charger` a besoin du plan intact.
    ///
    /// La `demande` est assemblée par `CibleChargement` : un plan calculé sur
    /// des entrées inventées côté iPhone serait un plan faux.
    public func planifier(demande: ValeurJSON) async throws -> ValeurJSON {
        try await client.lireOpaque(
            "POST", "inference/planifier", corps: .objet(["demande": demande])
        )
    }

    /// Rend un plan strictement PLUS conservateur après un échec.
    ///
    /// La cause est omise quand on ne l'a pas : le serveur reprend alors celle
    /// de l'échec qu'il a lui-même observé, ce qui vaut mieux que la
    /// supposition d'un téléphone.
    public func degrader(
        demande: ValeurJSON, planEchoue: ValeurJSON, cause: String? = nil
    ) async throws -> ValeurJSON {
        var corps: [String: ValeurJSON] = ["demande": demande, "plan_echoue": planEchoue]
        if let cause { corps["cause"] = .texte(cause) }
        return try await client.lireOpaque("POST", "inference/degrader", corps: .objet(corps))
    }

    /// Le plan actuellement appliqué, relu OPAQUE. `nil` quand rien n'est
    /// chargé — c'est l'état normal, pas une erreur.
    public func planCourant() async throws -> ApercuPlan? {
        let etat = try await client.lireOpaque("GET", "inference/etat")
        guard let plan = etat["plan"], !plan.estNul else { return nil }
        return ApercuPlan.lire(plan: plan)
    }

    /// Les derniers chargements : plan appliqué, déroulé, issue.
    public func journalChargements(limite: Int = 10) async throws -> [SessionChargement] {
        let brut = try await client.lireOpaque("GET", "inference/journal?limite=\(limite)")
        return (brut.listeOuNil ?? []).compactMap(SessionChargement.lire)
    }
}

/// Un chargement complet, tel que le serveur l'a journalisé.
///
/// Construit depuis `ValeurJSON` et non par `Decodable` : la session porte le
/// plan appliqué, et le décoder par le contrat typé en abîmerait les clés.
public struct SessionChargement: Sendable, Equatable, Identifiable {
    public let id: String
    public let modele: String
    public let moteur: String
    public let etat: EtatInference
    public let dureeS: Double?
    /// La cause QUALIFIÉE d'un échec — `vram_insuffisante`,
    /// `contexte_trop_grand`… La v1 remontait « Failed to load model from file »
    /// pour tout, et le message accusait le fichier quand la cause était
    /// ailleurs. `nil` quand le chargement a abouti.
    public let cause: String?
    public let message: String
    public let remediation: String
    public let plan: ApercuPlan?
    public let entrees: [EntreeJournal]

    /// « 12,4 s ». `nil` tant que le chargement n'est pas conclu.
    public var dureeLisible: String? {
        guard let dureeS else { return nil }
        return String(format: "%.1f s", dureeS).replacingOccurrences(of: ".", with: ",")
    }

    static func lire(_ brut: ValeurJSON) -> SessionChargement? {
        guard let identifiant = brut["identifiant"]?.texteOuNil else { return nil }
        return SessionChargement(
            id: identifiant,
            modele: brut["modele"]?.texteOuNil ?? "",
            moteur: brut["moteur"]?.texteOuNil ?? "",
            etat: brut["etat"]?.texteOuNil.flatMap(EtatInference.init(rawValue:)) ?? .inactif,
            dureeS: brut["duree_s"]?.nombreOuNil,
            cause: brut["cause"]?.texteOuNil,
            message: brut["message"]?.texteOuNil ?? "",
            remediation: brut["remediation"]?.texteOuNil ?? "",
            plan: brut["plan"].flatMap { ApercuPlan.lire(plan: $0) },
            entrees: EntreeJournal.lire(brut["entrees"])
        )
    }
}

/// Une étape du déroulé d'un chargement.
///
/// `☠` L'identité vient du RANG, jamais du contenu : deux étapes portent
/// couramment le même message (« attente du moteur »), et une `ForEach`
/// identifiée par le texte en perdrait une, sans erreur.
public struct EntreeJournal: Sendable, Equatable, Identifiable {
    public let id: Int
    public let phase: String
    public let niveau: String
    public let message: String

    public var estEchec: Bool { niveau == "erreur" }
    public var estAvertissement: Bool { niveau == "avertissement" }

    static func lire(_ brut: ValeurJSON?) -> [EntreeJournal] {
        (brut?.listeOuNil ?? []).enumerated().map { rang, entree in
            EntreeJournal(
                id: rang,
                phase: entree["phase"]?.texteOuNil ?? "",
                niveau: entree["niveau"]?.texteOuNil ?? "info",
                message: entree["message"]?.texteOuNil ?? ""
            )
        }
    }
}
