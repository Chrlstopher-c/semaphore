import Foundation

/// Ce qu'il faut envoyer au planificateur du PC pour qu'il calcule un plan.
///
/// `☠` Ce module existe parce que l'app postait au planificateur des documents
/// qu'il ne sait pas lire. `POST /inference/planifier` attend un
/// `MetadonneesModele` et un `ProfilMachine` **du planificateur** ; l'app lui
/// reposait la réponse brute de `/models/registre/{id}/metadonnees` (un
/// `MetadonneesGGUF` : `block_count`, `longueur_embedding`…) et celle de
/// `/system/profil` (un profil du domaine `system` : `gpus`, `memoire`…). Aucun
/// des champs requis ne porte le même nom — la requête ne pouvait rendre qu'un
/// 422, donc charger un modèle depuis le téléphone n'a jamais pu aboutir.
///
/// La conversion existe côté web dans `frontend/src/cible/conversion.ts`. Elle
/// est PORTÉE ici, avec sa règle fondatrice :
/// **ce qui n'a pas été lu ne s'invente pas.** Une métadonnée absente produit un
/// refus nommé, jamais une valeur par défaut — c'est la différence de fond avec
/// la v1, qui dérivait contexte et VRAM du nom d'un dépôt et se trompait.
///
/// Pur : aucun réseau ici, donc prouvable par `swift test` sur Linux.
public enum CibleChargement {

    /// Plateformes que le planificateur sait traiter. macOS et « inconnue » n'en
    /// font pas partie, et il vaut mieux le dire que produire un plan muet.
    static let plateformesPlanifiables: Set<String> = ["linux_natif", "wsl2", "windows"]

    /// La remédiation doit désigner une action qui EXISTE. Un conseil
    /// impossible à suivre est pire qu'aucun conseil : il fait chercher une
    /// issue là où il n'y en a pas.
    static let remedeMetadonnees = """
        Cette architecture ne déclare pas cette valeur dans son en-tête — le fichier n'est pas \
        en cause. Le rapport de cohérence du modèle détaille ce qui manque.
        """

    /// Ce que l'app envoie, et de quoi peindre l'écran pendant qu'elle attend.
    public struct Cible: Sendable, Equatable {
        public let cheminModele: String
        public let nomModele: String
        /// Les entrées mesurées du planificateur, prêtes à poster telles quelles.
        public let demande: ValeurJSON
    }

    public static func construire(
        modele: ModeleEnregistre,
        metadonnees: ValeurJSON,
        profil: ValeurJSON,
        statut: StatutInference?,
        preferences: PreferencesChargement = PreferencesChargement()
    ) -> Result<Cible, RefusCible> {
        let lues: ValeurJSON
        switch metadonneesPlan(modele, metadonnees) {
        case .failure(let refus): return .failure(refus)
        case .success(let valeur): lues = valeur
        }
        let machine: ValeurJSON
        switch profilPlan(profil, statut) {
        case .failure(let refus): return .failure(refus)
        case .success(let valeur): machine = valeur
        }
        return .success(Cible(
            cheminModele: modele.chemin,
            nomModele: modele.fichier ?? modele.depot,
            demande: .objet([
                "metadonnees": lues, "profil": machine, "preferences": preferences.valeur,
            ])
        ))
    }
}

/// Refus explicite : ce qui manque, et ce que Chris peut y faire. Distinct
/// d'une erreur réseau — rien n'a échoué, il n'y a simplement pas de quoi
/// calculer un plan.
public struct RefusCible: Sendable, Equatable, Error {
    public let manquant: String
    public let remediation: String

    public init(manquant: String, remediation: String) {
        self.manquant = manquant
        self.remediation = remediation
    }
}

/// Ce que Chris peut demander au planificateur. Tout est facultatif : le
/// planificateur décide seul et explique son choix, ce qui est le régime normal.
public struct PreferencesChargement: Sendable, Equatable {
    /// `nil` = aucune préférence. Jamais 0, qui serait une demande de contexte nul.
    public var contexte: Int?
    /// `f16`, `q8_0`, `q4_0`. Le défaut du planificateur.
    public var typeCacheKv: String
    public var flashAttention: Bool

    public init(contexte: Int? = nil, typeCacheKv: String = "f16", flashAttention: Bool = true) {
        self.contexte = contexte
        self.typeCacheKv = typeCacheKv
        self.flashAttention = flashAttention
    }

    /// `☠` `moteur` n'est PAS exposé. L'atelier ne pilote pas les moteurs
    /// (hors périmètre) : le laisser absent fait retenir au planificateur le
    /// seul moteur capable de lire le format, ce qu'il explique lui-même.
    var valeur: ValeurJSON {
        .objet([
            "contexte": contexte.map(ValeurJSON.entier) ?? .nul,
            "type_cache_kv": .texte(typeCacheKv),
            "flash_attention": .booleen(flashAttention),
        ])
    }
}

// MARK: - Métadonnées

extension CibleChargement {

    /// Les seuls champs sans lesquels aucun plan n'est calculable. Tous doivent
    /// être LUS dans l'en-tête ; aucun n'est dérivé.
    private static func metadonneesPlan(
        _ modele: ModeleEnregistre, _ gguf: ValeurJSON
    ) -> Result<ValeurJSON, RefusCible> {
        guard !gguf.estNul else {
            return .failure(RefusCible(
                manquant: "métadonnées illisibles pour \(modele.id)",
                remediation: modele.format == "gguf"
                    ? remedeMetadonnees
                    : "Le planificateur n'accepte aujourd'hui que des modèles GGUF."
            ))
        }
        var requis: [String: Int] = [:]
        for (cle, valeur, nom) in champsRequis(modele, gguf) {
            guard let valeur, valeur > 0 else {
                return .failure(RefusCible(
                    manquant: "\(nom) absent de l'en-tête GGUF", remediation: remedeMetadonnees
                ))
            }
            requis[cle] = valeur
        }
        return .success(assembler(modele, gguf, requis))
    }

    private static func champsRequis(
        _ modele: ModeleEnregistre, _ gguf: ValeurJSON
    ) -> [(String, Int?, String)] {
        [
            ("nombre_couches", gguf["block_count"]?.entierOuNil, "nombre de couches"),
            ("dimension_embedding", gguf["longueur_embedding"]?.entierOuNil, "dimension d'embedding"),
            // `largeur_ffn_active`, PAS `longueur_feed_forward` : cette dernière
            // n'existe pas sur une architecture MoE, qui déclare la largeur d'UN
            // expert. Le backend fait la somme réelle ; l'exiger bloquait tout MoE.
            ("dimension_ffn", gguf["largeur_ffn_active"]?.entierOuNil, "dimension FFN"),
            (
                "nombre_tetes_attention", gguf.chemin("attention", "nb_tetes")?.entierOuNil,
                "nombre de têtes d'attention"
            ),
            (
                "contexte_entrainement_max", gguf["contexte_natif"]?.entierOuNil,
                "contexte d'entraînement"
            ),
            ("taille_vocabulaire", gguf["taille_vocabulaire"]?.entierOuNil, "taille du vocabulaire"),
            ("taille_octets", modele.tailleOctets, "taille du fichier"),
        ]
    }

    private static func assembler(
        _ modele: ModeleEnregistre, _ gguf: ValeurJSON, _ requis: [String: Int]
    ) -> ValeurJSON {
        var champs = requis.mapValues(ValeurJSON.entier)
        champs["identifiant"] = .texte(modele.id)
        champs["format"] = .texte(modele.format)
        champs["architecture"] = .texte(gguf["architecture"]?.texteOuNil ?? "")
        // GQA : moins de têtes KV que de têtes Q. Non déclaré = pas de GQA, les
        // deux sont égales. C'est la convention du format, pas une estimation.
        champs["nombre_tetes_kv"] = .entier(
            gguf.chemin("attention", "nb_tetes_kv")?.entierOuNil
                ?? requis["nombre_tetes_attention"] ?? 0
        )
        // Laissé nul quand absent : le budget sait dériver, et Qwen3 déclare un
        // `head_dim` qui NE suit PAS la convention embedding/têtes.
        champs["dimension_tete"] = facultatif(gguf.chemin("attention", "dimension_cle"))
        champs["quantification"] = gguf["quantification_mesuree"]?.texteOuNil.map(ValeurJSON.texte)
            ?? gguf["quantification_declaree"]?.texteOuNil.map(ValeurJSON.texte) ?? .nul
        champs.merge(champsExperts(gguf)) { courant, _ in courant }
        champs.merge(champsRecurrents(gguf)) { courant, _ in courant }
        champs.merge(
            mesuresParBloc(gguf, requis["nombre_couches"] ?? 0)
        ) { courant, _ in courant }
        return .objet(champs)
    }

    /// Sans ces champs, le planificateur ne peut PAS déporter les experts et
    /// coupe par couches entières : sur un MoE, il fait alors payer au CPU toute
    /// l'attention d'une couche pour libérer des experts dont 8 sur 256 sont lus.
    private static func champsExperts(_ gguf: ValeurJSON) -> [String: ValeurJSON] {
        let nombre = gguf["nb_experts"]?.entierOuNil
        return [
            "est_moe": .booleen((nombre ?? 0) > 1),
            "nombre_experts": facultatif(gguf["nb_experts"]),
            "nombre_experts_actifs": facultatif(gguf["nb_experts_actifs"]),
            "dimension_ffn_expert": facultatif(gguf.chemin("experts", "largeur_ffn_expert")),
            "dimension_ffn_expert_partage": facultatif(
                gguf.chemin("experts", "largeur_ffn_partagee")
            ),
            "intervalle_attention_pleine": facultatif(
                gguf.chemin("attention", "intervalle_attention_pleine")
            ),
        ]
    }

    /// Sans ces trois lignes, l'état récurrent reste chiffré à zéro côté
    /// planificateur — et le plan promet une VRAM qu'il n'a pas.
    private static func champsRecurrents(_ gguf: ValeurJSON) -> [String: ValeurJSON] {
        [
            "dimension_interne_ssm": facultatif(gguf.chemin("ssm", "dimension_interne")),
            "dimension_etat_ssm": facultatif(gguf.chemin("ssm", "dimension_etat")),
            "noyau_convolution_ssm": facultatif(gguf.chemin("ssm", "noyau_convolution")),
        ]
    }

    /// Mesures par bloc, transmises seulement si elles sont COMPLÈTES.
    ///
    /// `☠` Le backend refuse une mesure dont la longueur ne fait pas
    /// `nombre_couches`, et il a raison : une mesure tronquée se lirait comme un
    /// modèle plus léger qu'il n'est, et le plan tiendrait sur le papier sans
    /// tenir en VRAM. Ici, incomplet vaut absent — le planificateur retombe sur
    /// la coupe par couches, ce qu'il sait faire et qu'il explique.
    private static func mesuresParBloc(
        _ gguf: ValeurJSON, _ nombreCouches: Int
    ) -> [String: ValeurJSON] {
        guard let mesures = gguf["mesures"], !mesures.estNul,
              let totaux = mesures["octets_par_bloc"]?.listeOuNil,
              let experts = mesures["octets_experts_par_bloc"]?.listeOuNil,
              totaux.count == nombreCouches, experts.count == nombreCouches else { return [:] }
        return [
            "octets_par_bloc": .liste(totaux),
            "octets_experts_par_bloc": .liste(experts),
            "octets_hors_blocs": facultatif(mesures["octets_hors_blocs"]),
        ]
    }

    /// Une valeur absente vaut `null` explicite, jamais une clé manquante : le
    /// contrat pydantic distingue les deux sur plusieurs champs.
    private static func facultatif(_ valeur: ValeurJSON?) -> ValeurJSON {
        guard let valeur, !valeur.estNul else { return .nul }
        return valeur
    }
}

// MARK: - Profil machine

extension CibleChargement {

    private static func profilPlan(
        _ profil: ValeurJSON, _ statut: StatutInference?
    ) -> Result<ValeurJSON, RefusCible> {
        guard let gpu = profil["gpu_principal"], !gpu.estNul else {
            return .failure(RefusCible(
                manquant: "aucun GPU mesuré",
                remediation: "Vérifier que la carte est bien exposée au conteneur d'EchoHub."
            ))
        }
        let plateforme = profil["plateforme"]?.texteOuNil ?? ""
        guard plateformesPlanifiables.contains(plateforme) else {
            return .failure(RefusCible(
                manquant: "plateforme « \(plateforme) » hors du champ du planificateur",
                remediation: "EchoHub doit tourner sous Linux natif, WSL2 ou Windows."
            ))
        }
        // `moteurs_disponibles` est délibérément ABSENT : le défaut du contrat
        // vaut « llama.cpp », le seul moteur que cet atelier pilote. Le relever
        // demanderait `/api/engines/*`, écarté du périmètre.
        return .success(.objet([
            "plateforme": .texte(plateforme),
            "index_gpu": .entier(gpu["index"]?.entierOuNil ?? 0),
            "nom_gpu": .texte(gpu["nom"]?.texteOuNil ?? ""),
            "vram_totale_octets": .entier(profil["vram_totale_octets"]?.entierOuNil ?? 0),
            "vram_libre_octets": .entier(profil["vram_libre_octets"]?.entierOuNil ?? 0),
            "ram_libre_octets": .entier(profil["ram_disponible_octets"]?.entierOuNil ?? 0),
            "modeles_charges": .liste(modelesCharges(statut)),
            "capacite_calcul": capaciteCalcul(gpu),
        ]))
    }

    private static func capaciteCalcul(_ gpu: ValeurJSON) -> ValeurJSON {
        guard let majeur = gpu["compute_majeur"]?.entierOuNil,
              let mineur = gpu["compute_mineur"]?.entierOuNil else { return .nul }
        return .liste([.entier(majeur), .entier(mineur)])
    }

    /// Le modèle qui occupe le GPU, s'il y en a un. Le planificateur en a besoin
    /// pour décider d'une éjection : le GPU est exclusif, et un chargement qui
    /// l'ignore échoue sur une VRAM déjà prise.
    ///
    /// `☠` La DIFFÉRENCE entre les deux mesures, jamais `vram_apres` seule.
    /// `vram_apres_octets` est la VRAM totale utilisée de la carte, bureau
    /// compris — la passer telle quelle dirait au planificateur qu'éjecter ce
    /// modèle rendrait aussi la mémoire du compositeur et du navigateur. Il
    /// visait alors la carte entière, ne déportait presque aucun expert, et le
    /// GPU refusait l'allocation : le modèle devenait inchargeable à TOUS les
    /// contextes. Mesuré côté bureau le 26/08/2026.
    static func modelesCharges(_ statut: StatutInference?) -> [ValeurJSON] {
        guard let statut, statut.etat == .pret, let moteur = statut.etatMoteur else { return [] }
        let avant = moteur.vramAvantOctets ?? 0
        let apres = moteur.vramApresOctets ?? 0
        return [.objet([
            "identifiant": .texte(moteur.modele),
            "moteur": .texte(moteur.moteur),
            "vram_octets": .entier(max(0, apres - avant)),
        ])]
    }
}
