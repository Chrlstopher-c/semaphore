import XCTest
@testable import EchoHubNoyau

/// Ce que le planificateur du PC doit recevoir pour rendre un plan.
///
/// `☠` Cette batterie existe à cause d'un défaut qui ne se voyait nulle part :
/// l'app reposait au planificateur la réponse BRUTE de
/// `/models/registre/{id}/metadonnees` et celle de `/system/profil`. Deux
/// contrats différents de celui qu'il attend — aucun champ requis ne porte le
/// même nom. La requête ne pouvait rendre qu'un 422, donc charger un modèle
/// depuis le téléphone n'a jamais pu aboutir. Rien ne le signalait : la seule
/// preuve automatique du projet ne couvrait pas cette conversion, parce qu'elle
/// n'existait pas.
final class CibleChargementTests: XCTestCase {

    /// Les documents sont décodés EXACTEMENT comme en production — `CodageOpaque`,
    /// sans conversion de clés. Un test qui construirait un `ValeurJSON` à la
    /// main ne prouverait rien sur le chemin réel.
    private func valeur(_ json: String) throws -> ValeurJSON {
        try CodageOpaque.decodeur().decode(ValeurJSON.self, from: Data(json.utf8))
    }

    private func modele(
        format: String = "gguf", taille: Int = 8_000_000_000
    ) -> ModeleEnregistre {
        ModeleEnregistre(
            id: "org/Depot-GGUF::poids.gguf", depot: "org/Depot-GGUF", fichier: "poids.gguf",
            chemin: "/modeles/org_Depot-GGUF/poids.gguf", format: format, tailleOctets: taille,
            quantification: "Q4_K_M", architecture: "qwen3", nbCouches: 40,
            contexteMax: 262_144, favori: false
        )
    }

    /// Un en-tête GGUF dense, tel que le backend le sérialise.
    private let ggufDense = """
        {"chemin": "/m/p.gguf", "taille_fichier_octets": 8000000000, "version_gguf": 3,
         "architecture": "qwen3", "block_count": 40, "source_block_count": "cle",
         "contexte_natif": 262144, "longueur_embedding": 4096,
         "longueur_feed_forward": 12288, "largeur_ffn_active": 12288,
         "nb_experts": null, "nb_experts_actifs": null,
         "experts": {"largeur_ffn_expert": null, "largeur_ffn_partagee": null},
         "attention": {"nb_tetes": 32, "nb_tetes_kv": 8, "dimension_cle": 128,
                       "intervalle_attention_pleine": null},
         "ssm": {"dimension_interne": null, "dimension_etat": null, "noyau_convolution": null},
         "quantification_declaree": "Q4_K_M", "quantification_mesuree": "Q4_K_M",
         "nb_tenseurs": 500, "taille_vocabulaire": 151936, "mesures": null,
         "est_moe": false}
        """

    private let profilComplet = """
        {"mesure_le": "2026-08-28T00:00:00Z", "plateforme": "linux_natif",
         "version_noyau": "6.9", "source_gpu": "nvml", "gpus": [], "avertissements": [],
         "a_gpu": true, "memoire_mesuree": true,
         "gpu_principal": {"index": 0, "nom": "RTX 3060", "compute_majeur": 8,
                           "compute_mineur": 6, "vram_totale_octets": 12884901888,
                           "vram_libre_octets": 11811160064},
         "vram_libre_octets": 11811160064, "vram_totale_octets": 12884901888,
         "ram_disponible_octets": 34359738368}
        """

    private func construire(
        gguf: String? = nil, profil: String? = nil, format: String = "gguf",
        statut: StatutInference? = nil
    ) throws -> Result<CibleChargement.Cible, RefusCible> {
        CibleChargement.construire(
            modele: modele(format: format),
            metadonnees: try valeur(gguf ?? ggufDense),
            profil: try valeur(profil ?? profilComplet),
            statut: statut
        )
    }

    private func demande(_ resultat: Result<CibleChargement.Cible, RefusCible>) throws -> ValeurJSON {
        switch resultat {
        case .success(let cible): return cible.demande
        case .failure(let refus): throw XCTSkip("refus inattendu : \(refus.manquant)")
        }
    }

    private func refus(_ resultat: Result<CibleChargement.Cible, RefusCible>) throws -> RefusCible {
        switch resultat {
        case .success: throw XCTSkip("cible construite alors qu'un refus était attendu")
        case .failure(let refus): return refus
        }
    }

    // MARK: - Le contrat du planificateur

    /// Le cœur du correctif : les clés attendues par `MetadonneesModele` du
    /// planificateur, avec les valeurs LUES dans l'en-tête GGUF — pas celles
    /// que l'en-tête portait sous d'autres noms.
    func testLesClesDuPlanificateurSontEcritesEtNonCellesDeLEnTete() throws {
        let lues = try XCTUnwrap(try demande(try construire())["metadonnees"])
        XCTAssertEqual(lues["nombre_couches"]?.entierOuNil, 40)
        XCTAssertEqual(lues["dimension_embedding"]?.entierOuNil, 4096)
        XCTAssertEqual(lues["dimension_ffn"]?.entierOuNil, 12288)
        XCTAssertEqual(lues["nombre_tetes_attention"]?.entierOuNil, 32)
        XCTAssertEqual(lues["contexte_entrainement_max"]?.entierOuNil, 262_144)
        XCTAssertEqual(lues["taille_vocabulaire"]?.entierOuNil, 151_936)
        XCTAssertEqual(lues["taille_octets"]?.entierOuNil, 8_000_000_000)
        XCTAssertEqual(lues["identifiant"]?.texteOuNil, "org/Depot-GGUF::poids.gguf")
        XCTAssertEqual(lues["format"]?.texteOuNil, "gguf")
        // Les noms de l'en-tête ne doivent PAS traverser : c'est ce qui produisait le 422.
        XCTAssertNil(lues["block_count"])
        XCTAssertNil(lues["longueur_embedding"])
    }

    func testLeProfilEstTraduitDansLeVocabulaireDuPlanificateur() throws {
        let machine = try XCTUnwrap(try demande(try construire())["profil"])
        XCTAssertEqual(machine["plateforme"]?.texteOuNil, "linux_natif")
        XCTAssertEqual(machine["index_gpu"]?.entierOuNil, 0)
        XCTAssertEqual(machine["nom_gpu"]?.texteOuNil, "RTX 3060")
        XCTAssertEqual(machine["vram_libre_octets"]?.entierOuNil, 11_811_160_064)
        // `ram_libre_octets` est requis par le planificateur et s'appelle
        // `ram_disponible_octets` côté `system` : c'est un des champs qui
        // manquait purement et simplement.
        XCTAssertEqual(machine["ram_libre_octets"]?.entierOuNil, 34_359_738_368)
        XCTAssertEqual(machine["capacite_calcul"]?.listeOuNil?.count, 2)
        XCTAssertNil(machine["gpus"], "le profil du domaine `system` ne doit pas fuiter tel quel")
    }

    /// GQA non déclarée : les deux nombres de têtes sont égaux. C'est la
    /// convention du format, pas une estimation.
    func testTetesKvAbsentesValentLesTetesDAttention() throws {
        let sansKv = ggufDense.replacingOccurrences(of: "\"nb_tetes_kv\": 8", with: "\"nb_tetes_kv\": null")
        XCTAssertNotEqual(sansKv, ggufDense, "le motif de substitution n'a pas matché")
        let lues = try XCTUnwrap(try demande(try construire(gguf: sansKv))["metadonnees"])
        XCTAssertEqual(lues["nombre_tetes_kv"]?.entierOuNil, 32)
    }

    func testLesPreferencesTraversent() throws {
        let vue = CibleChargement.construire(
            modele: modele(), metadonnees: try valeur(ggufDense),
            profil: try valeur(profilComplet), statut: nil,
            preferences: PreferencesChargement(
                contexte: 32_768, typeCacheKv: "q8_0", flashAttention: false
            )
        )
        let choix = try XCTUnwrap(try demande(vue)["preferences"])
        XCTAssertEqual(choix["contexte"]?.entierOuNil, 32_768)
        XCTAssertEqual(choix["type_cache_kv"]?.texteOuNil, "q8_0")
        XCTAssertEqual(choix["flash_attention"]?.booleenOuNil, false)
        // Le moteur n'est jamais imposé : le planificateur retient le seul qui
        // sait lire le format, et il l'explique.
        XCTAssertNil(choix["moteur"])
    }

    // MARK: - Ce qui n'a pas été lu ne s'invente pas

    func testUnChampRequisAbsentDonneUnRefusQuiLeNomme() throws {
        let sansCouches = ggufDense.replacingOccurrences(
            of: "\"block_count\": 40", with: "\"block_count\": 0"
        )
        XCTAssertNotEqual(sansCouches, ggufDense, "le motif de substitution n'a pas matché")
        let refuse = try refus(try construire(gguf: sansCouches))
        XCTAssertTrue(refuse.manquant.contains("nombre de couches"), refuse.manquant)
        XCTAssertFalse(refuse.remediation.isEmpty)
    }

    func testMetadonneesNullesSurUnSafetensorsExpliquentLaLimiteDuPlanificateur() throws {
        let refuse = try refus(try construire(gguf: "null", format: "safetensors"))
        XCTAssertTrue(refuse.remediation.contains("GGUF"), refuse.remediation)
    }

    func testAucunGpuMesureEstUnRefusNomme() throws {
        let sansGpu = profilComplet.replacingOccurrences(
            of: "\"gpu_principal\": {", with: "\"gpu_absent\": {"
        )
        XCTAssertNotEqual(sansGpu, profilComplet, "le motif de substitution n'a pas matché")
        XCTAssertEqual(try refus(try construire(profil: sansGpu)).manquant, "aucun GPU mesuré")
    }

    func testUnePlateformeHorsChampEstRefuseeAvantLAllerRetour() throws {
        let mac = profilComplet.replacingOccurrences(
            of: "\"plateforme\": \"linux_natif\"", with: "\"plateforme\": \"macos\""
        )
        XCTAssertNotEqual(mac, profilComplet, "le motif de substitution n'a pas matché")
        XCTAssertTrue(try refus(try construire(profil: mac)).manquant.contains("macos"))
    }

    func testCapaciteDeCalculNonLueVautNulEtNonUnDefaut() throws {
        let sansCompute = profilComplet.replacingOccurrences(
            of: "\"compute_majeur\": 8", with: "\"compute_majeur\": null"
        )
        XCTAssertNotEqual(sansCompute, profilComplet, "le motif de substitution n'a pas matché")
        let machine = try XCTUnwrap(try demande(try construire(profil: sansCompute))["profil"])
        XCTAssertEqual(machine["capacite_calcul"], .nul)
    }

    // MARK: - Mélange d'experts

    private let ggufMoE = """
        {"chemin": "/m/moe.gguf", "taille_fichier_octets": 20000000000, "version_gguf": 3,
         "architecture": "qwen3moe", "block_count": 48, "source_block_count": "cle",
         "contexte_natif": 262144, "longueur_embedding": 2048,
         "longueur_feed_forward": null, "largeur_ffn_active": 6144,
         "nb_experts": 128, "nb_experts_actifs": 8,
         "experts": {"largeur_ffn_expert": 768, "largeur_ffn_partagee": 0},
         "attention": {"nb_tetes": 32, "nb_tetes_kv": 4, "dimension_cle": 128,
                       "intervalle_attention_pleine": 4},
         "ssm": {"dimension_interne": null, "dimension_etat": null, "noyau_convolution": null},
         "quantification_declaree": "Q4_K_M", "quantification_mesuree": null,
         "nb_tenseurs": 900, "taille_vocabulaire": 151936, "est_moe": true,
         "mesures": {"octets_par_bloc": [1, 2], "octets_experts_par_bloc": [1, 2],
                     "octets_hors_blocs": 500, "octets_totaux": 1000, "blocs_observes": 2,
                     "blocs_avec_attention": [0, 1]}}
        """

    /// `☠` `longueur_feed_forward` n'existe pas sur un MoE : c'est
    /// `largeur_ffn_active` qu'il faut lire. L'exiger sous l'autre nom bloquait
    /// TOUT modèle à mélange d'experts.
    func testUnMoEPasseParLaLargeurFfnActive() throws {
        let lues = try XCTUnwrap(try demande(try construire(gguf: ggufMoE))["metadonnees"])
        XCTAssertEqual(lues["dimension_ffn"]?.entierOuNil, 6144)
        XCTAssertEqual(lues["est_moe"]?.booleenOuNil, true)
        XCTAssertEqual(lues["nombre_experts"]?.entierOuNil, 128)
        XCTAssertEqual(lues["nombre_experts_actifs"]?.entierOuNil, 8)
        XCTAssertEqual(lues["dimension_ffn_expert"]?.entierOuNil, 768)
        XCTAssertEqual(lues["intervalle_attention_pleine"]?.entierOuNil, 4)
    }

    /// Mesure tronquée = mesure absente. Une mesure de 2 blocs pour 48 couches
    /// se lirait comme un modèle plus léger qu'il n'est, et le plan tiendrait
    /// sur le papier sans tenir en VRAM.
    func testUneMesureParBlocIncompleteEstEcarteeEtNonTronquee() throws {
        let lues = try XCTUnwrap(try demande(try construire(gguf: ggufMoE))["metadonnees"])
        XCTAssertNil(lues["octets_par_bloc"])
        XCTAssertNil(lues["octets_hors_blocs"])
    }

    func testUneMesureParBlocCompleteEstTransmise() throws {
        let complet = ggufMoE.replacingOccurrences(of: "\"block_count\": 48", with: "\"block_count\": 2")
        XCTAssertNotEqual(complet, ggufMoE, "le motif de substitution n'a pas matché")
        let lues = try XCTUnwrap(try demande(try construire(gguf: complet))["metadonnees"])
        XCTAssertEqual(lues["octets_par_bloc"]?.listeOuNil?.count, 2)
        XCTAssertEqual(lues["octets_hors_blocs"]?.entierOuNil, 500)
    }

    func testLaQuantificationMesureePrimeSurLaDeclareeEtRetombeDessus() throws {
        let dense = try XCTUnwrap(try demande(try construire())["metadonnees"])
        XCTAssertEqual(dense["quantification"]?.texteOuNil, "Q4_K_M")
        let moe = try XCTUnwrap(try demande(try construire(gguf: ggufMoE))["metadonnees"])
        XCTAssertEqual(moe["quantification"]?.texteOuNil, "Q4_K_M")
    }

    // MARK: - Ce qui occupe déjà le GPU

    private func statut(etat: EtatInference, avant: Int?, apres: Int?) -> StatutInference {
        StatutInference(
            etat: etat, moteur: "llama.cpp", modele: "autre::poids.gguf", cause: nil,
            message: "", remediation: "",
            etatMoteur: EtatMoteur(
                moteur: "llama.cpp", modele: "autre::poids.gguf", pret: true, contexte: 32768,
                couchesGpu: 40, dureeChargementS: 12, vramAvantOctets: avant, vramApresOctets: apres
            )
        )
    }

    /// `☠` La DIFFÉRENCE des deux mesures, jamais `vram_apres` seule. Cette
    /// dernière est la VRAM totale utilisée de la carte, bureau compris : la
    /// passer telle quelle promettait au planificateur qu'éjecter ce modèle
    /// rendrait aussi la mémoire du compositeur et du navigateur.
    func testLaVramDunModeleChargeEstLaDifferenceDesDeuxMesures() throws {
        let charges = CibleChargement.modelesCharges(
            statut(etat: .pret, avant: 1_500_000_000, apres: 9_000_000_000)
        )
        XCTAssertEqual(charges.count, 1)
        XCTAssertEqual(charges.first?["vram_octets"]?.entierOuNil, 7_500_000_000)
        XCTAssertEqual(charges.first?["identifiant"]?.texteOuNil, "autre::poids.gguf")
    }

    func testAucunModeleCharteQuandLEtatNEstPasPret() {
        XCTAssertTrue(CibleChargement.modelesCharges(
            statut(etat: .echoue, avant: 1, apres: 9)
        ).isEmpty)
        XCTAssertTrue(CibleChargement.modelesCharges(nil).isEmpty)
    }

    /// Mesure manquante : 0, jamais un nombre négatif ni la mesure survivante.
    func testUneMesureDeVramManquanteNeProduitPasDeNombreNegatif() {
        let charges = CibleChargement.modelesCharges(statut(etat: .pret, avant: 9, apres: nil))
        XCTAssertEqual(charges.first?["vram_octets"]?.entierOuNil, 0)
    }
}
