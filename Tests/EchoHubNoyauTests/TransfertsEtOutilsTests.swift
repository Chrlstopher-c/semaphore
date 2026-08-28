import XCTest
@testable import EchoHubNoyau

/// Ce qu'une trame de progression porte, et ce qu'on en fait.
final class LectureTransfertTests: XCTestCase {

    private func trame(_ donnees: String) -> TrameSSE {
        TrameSSE(evenement: nil, donnees: donnees)
    }

    private let enCours = """
        {"identifiant": "org/D-GGUF::p.gguf", "depot": "org/D-GGUF", "fichier": "p.gguf",
         "revision": "main", "chemin": "/m/org_D-GGUF", "etat": "en_cours",
         "octets_recus": 4294967296, "octets_totaux": 8589934592, "erreur": null,
         "remediation": null, "demarre_le": "2026-08-28T00:00:00Z",
         "maj_le": "2026-08-28T00:01:00Z", "termine_le": null, "progression": 0.5}
        """

    func testUnEtatCompletEstLuTelQuel() throws {
        guard case .etat(let transfert) = try XCTUnwrap(LectureTransfert.lire(trame(enCours))) else {
            return XCTFail("la trame n'a pas été lue comme un état")
        }
        XCTAssertEqual(transfert.etat, .enCours)
        XCTAssertTrue(transfert.actif)
        XCTAssertEqual(transfert.progression, 0.5)
        XCTAssertEqual(transfert.avancement, "4,0 Go sur 8,0 Go")
    }

    /// `☠` Pas de pourcentage quand le Hub n'a pas annoncé les tailles. Un
    /// « 4,0 Go sur 0 » ou un « 0 % » figé sont pires qu'un chiffre seul :
    /// ils décrivent un transfert qui n'avance pas.
    func testSansTotalAnnonceIlNYAPasDePourcentage() throws {
        let sansTotal = enCours.replacingOccurrences(
            of: "\"octets_totaux\": 8589934592", with: "\"octets_totaux\": null"
        )
        XCTAssertNotEqual(sansTotal, enCours, "le motif de substitution n'a pas matché")
        let sansProgression = sansTotal.replacingOccurrences(
            of: "\"progression\": 0.5", with: "\"progression\": null"
        )
        guard case .etat(let transfert) = try XCTUnwrap(
            LectureTransfert.lire(trame(sansProgression))
        ) else {
            return XCTFail("la trame n'a pas été lue comme un état")
        }
        XCTAssertNil(transfert.progression)
        XCTAssertEqual(transfert.avancement, "4,0 Go")
    }

    /// `☠` Le serveur émet ses erreurs métier DANS le flux : le statut HTTP est
    /// déjà parti. Une trame d'erreur prise pour une trame inconnue laisserait
    /// l'écran attendre une fin qui ne viendra pas.
    func testUneErreurEmiseDansLeFluxDevientUnEchec() throws {
        let charge = """
            {"code": "telechargement_echoue", "message": "Dépôt introuvable.",
             "remediation": "Vérifier le nom du dépôt."}
            """
        guard case .echec(let raison) = try XCTUnwrap(LectureTransfert.lire(trame(charge))) else {
            return XCTFail("une erreur du flux n'a pas été reconnue")
        }
        XCTAssertEqual(raison, "Dépôt introuvable. Vérifier le nom du dépôt.")
    }

    func testLaSentinelleTermineLeSuivi() throws {
        XCTAssertEqual(LectureTransfert.lire(trame("[DONE]")), .fin)
        XCTAssertEqual(LectureTransfert.lire(trame("  [DONE]  ")), .fin)
    }

    /// Une trame vide ou incompréhensible est IGNORÉE, jamais fatale : un
    /// commentaire de garde-en-vie ne doit pas couper un suivi de deux heures.
    func testUneTrameIncomprehensibleEstIgnoreeSansCouperLeSuivi() {
        XCTAssertNil(LectureTransfert.lire(trame("")))
        XCTAssertNil(LectureTransfert.lire(trame("{\"inattendu\": 1}")))
    }

    func testLesEtatsTerminauxNeSontPasActifs() {
        for brut in ["termine", "annule", "erreur", "interrompu"] {
            let charge = enCours.replacingOccurrences(
                of: "\"etat\": \"en_cours\"", with: "\"etat\": \"\(brut)\""
            )
            XCTAssertNotEqual(charge, enCours, "le motif de substitution n'a pas matché")
            guard case .etat(let transfert) = LectureTransfert.lire(trame(charge)) else {
                return XCTFail("état « \(brut) » non lu")
            }
            XCTAssertFalse(transfert.actif, "« \(brut) » ne doit pas compter comme actif")
        }
    }
}

/// Le défaut d'outils appliqué aux conversations neuves, et les TROIS états que
/// le contrat du serveur distingue.
final class OutilsParDefautTests: XCTestCase {

    private func corps(_ creation: CreationConversation) throws -> String {
        String(decoding: try CodageJSON.encodeur().encode(creation), as: UTF8.self)
    }

    /// `☠` « Hériter du registre » ne s'envoie PAS : le champ `reglages`
    /// disparaît, et le serveur applique ses propres défauts. Envoyer un objet
    /// vide donnerait le même résultat, mais par accident.
    func testHeriterDuRegistreNEnvoieAucunReglage() throws {
        let ecrit = try corps(CreationConversation(outilsParDefaut: SelectionOutils()))
        XCTAssertFalse(ecrit.contains("reglages"), ecrit)
        XCTAssertFalse(ecrit.contains("outils_actifs"), ecrit)
    }

    /// `[]` = aucun outil. C'est le cas que la confusion des trois états
    /// détruisait : une conversation neuve censée n'avoir aucun outil en
    /// retrouvait dix.
    func testAucunOutilSEnvoieCommeListeVideEtNonCommeAbsence() throws {
        let ecrit = try corps(
            CreationConversation(outilsParDefaut: SelectionOutils(outilsActifs: []))
        )
        XCTAssertTrue(ecrit.contains("\"outils_actifs\":[]"), ecrit)
    }

    func testUneSelectionExpliciteTraverseEnSnakeCase() throws {
        let ecrit = try corps(CreationConversation(
            outilsParDefaut: SelectionOutils(outilsActifs: ["lire_fichier", "chercher_web"])
        ))
        XCTAssertTrue(ecrit.contains("\"outils_actifs\""), ecrit)
        XCTAssertTrue(ecrit.contains("lire_fichier"), ecrit)
        XCTAssertFalse(ecrit.contains("outilsActifs"), "la clé doit partir en snake_case")
    }

    /// `☠` « Tous » et « 9 sur 9 » ne disent pas la même chose : le premier
    /// suivra le registre quand un dixième outil y sera enregistré. La phrase
    /// affichée doit porter cette différence.
    func testLeResumeDistingueHeriterDeToutCocher() {
        XCTAssertEqual(SelectionOutils().resume(surTotal: 9), "Tous les outils du PC")
        XCTAssertEqual(
            SelectionOutils(outilsActifs: (1...9).map { "o\($0)" }).resume(surTotal: 9),
            "9 sur 9"
        )
        XCTAssertEqual(SelectionOutils(outilsActifs: []).resume(surTotal: 9), "Aucun outil")
        XCTAssertEqual(SelectionOutils(outilsActifs: ["a"]).resume(surTotal: nil), "1 outils choisis")
    }

    /// Ce qui décide d'afficher ou non le rappel au-dessus du composeur : quand
    /// rien n'est coupé, le fil reste nu.
    func testSeuleUneSelectionRestreinteSeSignale() {
        XCTAssertFalse(SelectionOutils().restreinte)
        XCTAssertTrue(SelectionOutils(outilsActifs: []).restreinte)
        XCTAssertTrue(SelectionOutils(outilsActifs: ["a"]).restreinte)
    }

    /// Le magasin retombe sur l'état le plus SÛR — hériter du registre — quand
    /// le fichier est absent ou abîmé. Jamais « aucun outil », qui priverait le
    /// modèle de tout sans que personne ne l'ait demandé.
    func testUnDefautIllisibleRetombeSurHeriterDuRegistre() throws {
        let dossier = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("echohub-outils-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let magasin = MagasinOutilsParDefautDisque(dossier: dossier)

        XCTAssertNil(magasin.charger().outilsActifs, "fichier absent")

        magasin.sauvegarder(SelectionOutils(outilsActifs: []))
        XCTAssertEqual(magasin.charger().outilsActifs, [], "un aller-retour garde « aucun »")

        try Data("pas du json".utf8).write(
            to: dossier.appendingPathComponent("outils-par-defaut.json")
        )
        XCTAssertNil(magasin.charger().outilsActifs, "fichier abîmé")
    }
}
