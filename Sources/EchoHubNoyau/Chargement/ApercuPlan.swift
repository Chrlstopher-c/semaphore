import Foundation

/// Ce qu'on LIT d'un plan de chargement pour l'afficher, et rien de plus.
///
/// `☠` Le plan reste opaque de bout en bout (`ValeurJSON`) : c'est lui qu'on
/// repose au serveur pour charger, et une clé abîmée à l'aller-retour donnerait
/// un corps que pydantic refuse. Ce module ne le transforme JAMAIS — il le lit.
/// Porter les trois cents lignes de DTO du planificateur pour afficher huit
/// lignes coûterait une divergence à chaque évolution du serveur.
///
/// `☠` Aucune valeur n'est recalculée ici. `couches_cpu`, `vram_restante` et le
/// total du budget sont des `@property` Python NON sérialisées : on les
/// reconstitue par soustraction de champs présents, jamais par une règle
/// métier réinventée côté téléphone. Le planificateur reste seule autorité.
///
/// Pur : prouvable par `swift test`.
public struct ApercuPlan: Sendable, Equatable {
    /// Une décision du plan et la phrase qui l'explique.
    public struct Ligne: Sendable, Equatable, Identifiable {
        public var id: String { libelle }
        public let libelle: String
        public let valeur: String
        public let justification: String
        /// La machine a imposé cette valeur là où Chris en demandait une autre.
        /// La v1 rabotait sans le dire, et on croyait tourner avec le demandé.
        public let plafonnee: Bool
    }

    /// Un poste du budget VRAM, tel que le planificateur l'a chiffré.
    public struct Poste: Sendable, Equatable, Identifiable {
        public var id: String { libelle }
        public let libelle: String
        public let octets: Int
        public let justification: String
    }

    public let modele: String
    public let moteur: String
    public let couchesGpu: Int
    public let couchesTotales: Int
    public let contexte: Int
    /// Nombre de groupes d'experts rappelés en mémoire hôte. `nil` = axe sans
    /// objet (modèle dense) ; 0 = MoE dont tout tient en VRAM. Deux états
    /// différents, jamais confondus.
    public let expertsDeportes: Int?
    /// Combien de fois le plan a déjà été dégradé. 0 = plan d'origine.
    public let niveauDegradation: Int
    public let lignes: [Ligne]
    public let postes: [Poste]
    public let vramDisponibleOctets: Int
    public let ejections: [String]
    public let avertissements: [String]

    /// La VRAM que ce plan engage : la somme des postes chiffrés. Le serveur ne
    /// la sérialise pas (c'est une `@property`), on l'additionne ici sans rien
    /// décider.
    public var vramRequiseOctets: Int { postes.reduce(0) { $0 + $1.octets } }

    public var vramRestanteOctets: Int { vramDisponibleOctets - vramRequiseOctets }

    /// La part de la VRAM disponible que le plan consomme, de 0 à 1. `nil`
    /// quand rien n'est mesuré — jamais 0, qui se lirait « il ne prend rien ».
    public var part: Double? {
        guard vramDisponibleOctets > 0 else { return nil }
        return min(Double(vramRequiseOctets) / Double(vramDisponibleOctets), 1)
    }

    public var couchesCpu: Int { max(0, couchesTotales - couchesGpu) }
}

extension ApercuPlan {

    /// Lit la réponse de `/planifier` ou `/degrader` : `{plan, justifications,
    /// avertissements}`. `nil` quand le document ne porte pas de plan — la vue
    /// affiche alors un échec, jamais un plan à moitié inventé.
    public static func lire(reponse: ValeurJSON) -> ApercuPlan? {
        guard let plan = reponse["plan"], !plan.estNul else { return nil }
        return lire(plan: plan, avertissements: textes(reponse["avertissements"]))
    }

    /// Lit un plan seul — celui que `/inference/etat` rend avec le statut.
    public static func lire(plan: ValeurJSON, avertissements: [String] = []) -> ApercuPlan? {
        guard let couchesTotales = plan["couches_totales"]?.entierOuNil else { return nil }
        let deportes = plan["experts_deportes"]
        return ApercuPlan(
            modele: plan["identifiant_modele"]?.texteOuNil ?? "",
            moteur: justifiee(plan["moteur"])?.valeur ?? "",
            couchesGpu: justifiee(plan["couches_gpu"])?.entier ?? 0,
            couchesTotales: couchesTotales,
            contexte: justifiee(plan["contexte"])?.entier ?? 0,
            expertsDeportes: deportes.flatMap { $0.estNul ? nil : justifiee($0)?.compte },
            niveauDegradation: plan["niveau_degradation"]?.entierOuNil ?? 0,
            lignes: lignes(plan),
            postes: postes(plan.chemin("budget", "postes")),
            vramDisponibleOctets: plan.chemin("budget", "vram_disponible_octets")?.entierOuNil ?? 0,
            ejections: ejections(plan["ejections_requises"]),
            avertissements: avertissements.isEmpty
                ? textes(plan["avertissements"]) : avertissements
        )
    }

    /// L'ordre est celui de l'affichage attendu par l'interface de bureau —
    /// repris tel quel pour que les deux écrans racontent la même histoire.
    private static func lignes(_ plan: ValeurJSON) -> [Ligne] {
        let champs: [(String, String)] = [
            ("Moteur", "moteur"), ("Couches sur GPU", "couches_gpu"),
            ("Experts en mémoire hôte", "experts_deportes"), ("Contexte", "contexte"),
            ("Lot de prompt", "batch"), ("Cache KV", "type_cache_kv"),
            ("Flash attention", "flash_attention"),
        ]
        return champs.compactMap { libelle, cle in
            guard let brute = plan[cle], !brute.estNul, let lue = justifiee(brute) else { return nil }
            return Ligne(
                libelle: libelle,
                valeur: cle == "experts_deportes"
                    ? "\(lue.compte ?? 0) groupes" : lue.valeur,
                justification: lue.justification,
                plafonnee: lue.plafonnee
            )
        }
    }

    private static func postes(_ brute: ValeurJSON?) -> [Poste] {
        (brute?.listeOuNil ?? []).compactMap { poste in
            guard let libelle = poste["libelle"]?.texteOuNil,
                  let octets = poste["octets"]?.entierOuNil else { return nil }
            return Poste(
                libelle: libelle, octets: octets,
                justification: poste["justification"]?.texteOuNil ?? ""
            )
        }
    }

    private static func ejections(_ brute: ValeurJSON?) -> [String] {
        (brute?.listeOuNil ?? []).compactMap { $0["identifiant"]?.texteOuNil }
    }

    static func textes(_ brute: ValeurJSON?) -> [String] {
        (brute?.listeOuNil ?? []).compactMap(\.texteOuNil)
    }

    /// Une `ValeurJustifiee<T>` du planificateur, rendue affichable quel que
    /// soit le type porté — entier, booléen, texte, ou liste d'index.
    private struct Justifiee {
        let valeur: String
        let justification: String
        let plafonnee: Bool
        let entier: Int?
        let compte: Int?
    }

    private static func justifiee(_ brute: ValeurJSON?) -> Justifiee? {
        guard let brute, let portee = brute["valeur"] else { return nil }
        return Justifiee(
            valeur: rendre(portee),
            justification: brute["justification"]?.texteOuNil ?? "",
            plafonnee: brute["plafonnee"]?.booleenOuNil ?? false,
            entier: portee.entierOuNil,
            compte: portee.listeOuNil?.count
        )
    }

    private static func rendre(_ valeur: ValeurJSON) -> String {
        if let texte = valeur.texteOuNil { return texte }
        if let entier = valeur.entierOuNil { return "\(entier)" }
        if let booleen = valeur.booleenOuNil { return booleen ? "oui" : "non" }
        if let liste = valeur.listeOuNil { return "\(liste.count)" }
        if let nombre = valeur.nombreOuNil {
            return String(format: "%.2f", nombre).replacingOccurrences(of: ".", with: ",")
        }
        return "—"
    }
}
