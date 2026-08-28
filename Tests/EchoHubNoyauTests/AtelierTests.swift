import XCTest
@testable import EchoHubNoyau

/// Ce que l'atelier lit du PC : un plan, une fiche de modèle, une requête au
/// Hub, une trame de progression. Tout ce qui est pur dans le nouveau domaine.
final class ApercuPlanTests: XCTestCase {

    private func valeur(_ json: String) throws -> ValeurJSON {
        try CodageOpaque.decodeur().decode(ValeurJSON.self, from: Data(json.utf8))
    }

    /// Un plan tel que `/inference/planifier` le rend, réduit à ce que l'écran
    /// lit — les autres champs traversent sans être compris.
    private let reponse = """
        {"plan": {"identifiant_modele": "org/D::p.gguf", "niveau_degradation": 1,
          "couches_totales": 40,
          "moteur": {"valeur": "llama.cpp", "justification": "Seul moteur installé.",
                     "plafonnee": false},
          "couches_gpu": {"valeur": 29, "justification": "Budget VRAM.", "plafonnee": true},
          "contexte": {"valeur": 32768, "justification": "Demandé.", "plafonnee": false},
          "batch": {"valeur": 512, "justification": "Défaut.", "plafonnee": false},
          "type_cache_kv": {"valeur": "q8_0", "justification": "Économie.", "plafonnee": false},
          "flash_attention": {"valeur": true, "justification": "Supportée.", "plafonnee": false},
          "experts_deportes": {"valeur": [3, 7, 11], "justification": "Déport.",
                               "plafonnee": false},
          "ejections_requises": [{"identifiant": "autre::x.gguf", "moteur": "llama.cpp",
                                  "vram_liberee_octets": 7000000000, "raison": "GPU exclusif."}],
          "budget": {"vram_disponible_octets": 12000000000,
                     "postes": [{"libelle": "Poids", "octets": 8000000000,
                                 "justification": "29 couches."},
                                {"libelle": "Cache KV", "octets": 1000000000,
                                 "justification": "32k en q8_0."}]},
          "avertissements": ["Contexte plafonné."]},
         "justifications": ["Moteur : llama.cpp — Seul moteur installé."],
         "avertissements": ["Contexte plafonné par la VRAM."]}
        """

    func testLePlanEstLuSansEtreRecalcule() throws {
        let apercu = try XCTUnwrap(ApercuPlan.lire(reponse: try valeur(reponse)))
        XCTAssertEqual(apercu.modele, "org/D::p.gguf")
        XCTAssertEqual(apercu.moteur, "llama.cpp")
        XCTAssertEqual(apercu.couchesGpu, 29)
        XCTAssertEqual(apercu.couchesTotales, 40)
        XCTAssertEqual(apercu.contexte, 32768)
        XCTAssertEqual(apercu.niveauDegradation, 1)
        XCTAssertEqual(apercu.ejections, ["autre::x.gguf"])
    }

    /// `couches_cpu`, le total du budget et le reste sont des `@property`
    /// Python NON sérialisées : elles se reconstituent par soustraction de
    /// champs présents, jamais par une règle métier réinventée ici.
    func testLesGrandeursNonSerialiseesSeReconstituentParSoustraction() throws {
        let apercu = try XCTUnwrap(ApercuPlan.lire(reponse: try valeur(reponse)))
        XCTAssertEqual(apercu.couchesCpu, 11)
        XCTAssertEqual(apercu.vramRequiseOctets, 9_000_000_000)
        XCTAssertEqual(apercu.vramRestanteOctets, 3_000_000_000)
        XCTAssertEqual(apercu.part.map { ($0 * 100).rounded() }, 75)
    }

    /// `plafonnee` distingue « la machine a imposé » de « Chris a choisi ».
    /// C'est ce qui manquait à la v1 : elle rabotait sans le dire.
    func testUneValeurPlafonneeEstSignaleeCommeTelle() throws {
        let apercu = try XCTUnwrap(ApercuPlan.lire(reponse: try valeur(reponse)))
        let couches = try XCTUnwrap(apercu.lignes.first { $0.libelle == "Couches sur GPU" })
        XCTAssertTrue(couches.plafonnee)
        XCTAssertEqual(couches.valeur, "29")
        let contexte = try XCTUnwrap(apercu.lignes.first { $0.libelle == "Contexte" })
        XCTAssertFalse(contexte.plafonnee)
    }

    func testLesLignesSuiventLOrdreDeLInterfaceDeBureau() throws {
        let apercu = try XCTUnwrap(ApercuPlan.lire(reponse: try valeur(reponse)))
        XCTAssertEqual(apercu.lignes.map(\.libelle), [
            "Moteur", "Couches sur GPU", "Experts en mémoire hôte", "Contexte",
            "Lot de prompt", "Cache KV", "Flash attention",
        ])
    }

    /// `☠` `null` = axe sans objet (modèle dense) ; `[]` = MoE dont tout tient
    /// en VRAM. Deux états, jamais confondus : le premier n'a pas de ligne, le
    /// second en a une qui dit « 0 groupes ».
    /// Un plan minimal où seul le déport varie : c'est le seul axe éprouvé ici,
    /// et le construire à part évite de dépendre de l'indentation d'un fixture.
    private func planAvecDeport(_ deport: String) -> String {
        """
        {"identifiant_modele": "org/D::p.gguf", "couches_totales": 40,
         "couches_gpu": {"valeur": 40, "justification": "Toutes.", "plafonnee": false},
         "experts_deportes": \(deport)}
        """
    }

    func testDeportSansObjetEtDeportVideNeSeConfondentPas() throws {
        XCTAssertEqual(
            ApercuPlan.lire(reponse: try valeur(reponse))?.expertsDeportes, 3,
            "trois groupes déportés doivent se compter"
        )

        let dense = try XCTUnwrap(ApercuPlan.lire(plan: try valeur(planAvecDeport("null"))))
        XCTAssertNil(dense.expertsDeportes, "un modèle dense n'a pas d'axe de déport")
        XCTAssertNil(dense.lignes.first { $0.libelle == "Experts en mémoire hôte" })

        let tenant = try XCTUnwrap(ApercuPlan.lire(plan: try valeur(
            planAvecDeport("{\"valeur\": [], \"justification\": \"Tout tient.\", \"plafonnee\": false}")
        )))
        XCTAssertEqual(tenant.expertsDeportes, 0, "un MoE qui tient en VRAM déporte zéro groupe")
        XCTAssertEqual(
            tenant.lignes.first { $0.libelle == "Experts en mémoire hôte" }?.valeur, "0 groupes"
        )
    }

    /// Un document sans plan ne donne PAS un plan à moitié inventé : la vue
    /// affiche un échec, ce qui est la vérité.
    func testUnDocumentSansPlanNeDonneRien() throws {
        XCTAssertNil(ApercuPlan.lire(reponse: try valeur("{\"plan\": null}")))
        XCTAssertNil(ApercuPlan.lire(plan: try valeur("{\"identifiant_modele\": \"x\"}")))
    }

    /// Les avertissements de la réponse priment sur ceux du plan : c'est la
    /// couche qui a vu la demande de Chris, pas seulement le calcul.
    func testLesAvertissementsDeLaReponsePriment() throws {
        let apercu = try XCTUnwrap(ApercuPlan.lire(reponse: try valeur(reponse)))
        XCTAssertEqual(apercu.avertissements, ["Contexte plafonné par la VRAM."])
    }
}

final class FicheMetadonneesTests: XCTestCase {

    private func valeur(_ json: String) throws -> ValeurJSON {
        try CodageOpaque.decodeur().decode(ValeurJSON.self, from: Data(json.utf8))
    }

    private let gguf = """
        {"architecture": "qwen3", "block_count": 40, "contexte_natif": 262144,
         "longueur_embedding": 4096, "taille_vocabulaire": 151936, "nb_tenseurs": 500,
         "taille_fichier_octets": 8589934592,
         "attention": {"nb_tetes": 32, "nb_tetes_kv": 8},
         "quantification_declaree": "Q4_K_M", "quantification_mesuree": null,
         "nb_experts": null, "nb_experts_actifs": null}
        """

    func testLaFicheLitLEnTeteSansRienDeriver() throws {
        let fiche = try XCTUnwrap(FicheMetadonnees.lire(try valeur(gguf)))
        XCTAssertEqual(fiche.architecture, "qwen3")
        XCTAssertEqual(fiche.quantification, "Q4_K_M")
        XCTAssertEqual(fiche.contexteNatif, 262_144)
        XCTAssertFalse(fiche.estMoE)
        let valeurs = Dictionary(uniqueKeysWithValues: fiche.lignes.map { ($0.libelle, $0.valeur) })
        XCTAssertEqual(valeurs["Contexte natif"], "256 k")
        XCTAssertEqual(valeurs["Têtes d'attention"], "32 / 8 KV")
        XCTAssertEqual(valeurs["Fichier"], "8,0 Go")
    }

    /// `☠` Un champ absent fait DISPARAÎTRE sa ligne. Il n'affiche jamais un 0
    /// ni un tiret, qui se liraient comme une mesure.
    func testUnChampAbsentNAffichePasDeLigne() throws {
        let sansVocabulaire = gguf.replacingOccurrences(
            of: "\"taille_vocabulaire\": 151936", with: "\"taille_vocabulaire\": null"
        )
        XCTAssertNotEqual(sansVocabulaire, gguf, "le motif de substitution n'a pas matché")
        let fiche = try XCTUnwrap(FicheMetadonnees.lire(try valeur(sansVocabulaire)))
        XCTAssertNil(fiche.lignes.first { $0.libelle == "Vocabulaire" })
    }

    /// Sans GQA, les deux nombres sont égaux : afficher « 32 / 32 KV » ferait
    /// croire à une distinction qui n'existe pas.
    func testSansGqaLesTetesSAffichentSansLeDetailKv() throws {
        let sansGqa = gguf.replacingOccurrences(
            of: "\"nb_tetes_kv\": 8", with: "\"nb_tetes_kv\": 32"
        )
        XCTAssertNotEqual(sansGqa, gguf, "le motif de substitution n'a pas matché")
        let fiche = try XCTUnwrap(FicheMetadonnees.lire(try valeur(sansGqa)))
        XCTAssertEqual(fiche.lignes.first { $0.libelle == "Têtes d'attention" }?.valeur, "32")
    }

    func testUnModeleNonGgufNaPasDeFiche() throws {
        XCTAssertNil(FicheMetadonnees.lire(try valeur("null")))
    }
}

final class DemandeRechercheTests: XCTestCase {

    /// `☠` Les paramètres répétés s'écrivent en répétant la CLÉ. FastAPI lit
    /// une `list[…]` de cette façon ; une virgule serait avalée dans une seule
    /// valeur qu'aucun format ne reconnaît.
    func testLesListesRepetentLaCle() {
        let demande = DemandeRecherche(
            requete: "qwen", formats: ["gguf"], capacites: ["vision", "appel_outils"]
        )
        XCTAssertTrue(demande.chemin.contains("capacites=vision"), demande.chemin)
        XCTAssertTrue(demande.chemin.contains("capacites=appel_outils"), demande.chemin)
        XCTAssertFalse(demande.chemin.contains("vision,"), demande.chemin)
    }

    /// Un espace, un `&` ou un `+` dans la requête ne doivent pas casser la
    /// chaîne : `urlQueryAllowed` les laisserait passer, d'où l'encodage étroit.
    func testUneRequeteAvecDesCaracteresDeRequeteEstEncodee() {
        let chemin = DemandeRecherche(requete: "qwen 3 & moe+vl").chemin
        XCTAssertTrue(chemin.contains("requete=qwen%203%20%26%20moe%2Bvl"), chemin)
    }

    func testLaPaginationEtLeTriTraversent() {
        let chemin = DemandeRecherche(requete: "a", tri: .tendance, page: 2, taillePage: 50).chemin
        XCTAssertTrue(chemin.contains("tri=trending_score"), chemin)
        XCTAssertTrue(chemin.contains("page=2"), chemin)
        XCTAssertTrue(chemin.contains("taille_page=50"), chemin)
    }

    /// Le chemin part avec sa requête du bon côté du `?` : c'est le piège que
    /// `ClientEchoHub.url` existe pour éviter, et il faut que l'entrée le
    /// respecte aussi.
    func testLeCheminSAssembleEnUneUrlCorrecte() {
        let base = URL(string: "https://exemple.test")!
        let url = ClientEchoHub.url(base: base, chemin: DemandeRecherche(requete: "qwen").chemin)
        XCTAssertEqual(url?.path, "/api/models/recherche")
        XCTAssertTrue(url?.query?.contains("requete=qwen") ?? false)
    }
}

final class IdentifiantDansUneUrlTests: XCTestCase {

    /// `☠` Un identifiant de registre vaut `<depot>::<fichier>` et le dépôt
    /// contient un `/`. Le serveur déclare ces routes en `{identifiant:path}`
    /// précisément pour ça. L'app pose les segments tels quels : il faut donc
    /// vérifier que rien ne les échappe en route, sans quoi TOUTES les routes
    /// de fiche répondraient 404 sur un modèle venu du Hub.
    func testUnIdentifiantAvecSlashEtDeuxPointsResteUnChemin() {
        let base = URL(string: "https://exemple.test")!
        let identifiant = "mradermacher/Qwen3-27B-GGUF::Qwen3-27B.Q4_K_M.gguf"
        let url = ClientEchoHub.url(base: base, chemin: "models/registre/\(identifiant)/coherence")
        XCTAssertEqual(
            url?.absoluteString,
            "https://exemple.test/api/models/registre/mradermacher/Qwen3-27B-GGUF::"
                + "Qwen3-27B.Q4_K_M.gguf/coherence"
        )
    }

    func testUnIdentifiantDeTransfertGardeSaRequete() {
        let base = URL(string: "https://exemple.test")!
        let url = ClientEchoHub.url(
            base: base,
            chemin: "models/telechargements/org/D-GGUF::p.gguf?supprimer_fichiers=true"
        )
        XCTAssertEqual(url?.path, "/api/models/telechargements/org/D-GGUF::p.gguf")
        XCTAssertEqual(url?.query, "supprimer_fichiers=true")
    }
}
