import XCTest
@testable import DuplexNoyau

/// Le jumelage est ce que Chris fait UNE fois par PC. S'il doit le refaire
/// chaque semaine, le monde est raté ; s'il reste coincé sur un jeton mort, il
/// n'a aucun moyen d'en sortir. Les deux se jouent dans cette machine, et elle
/// s'éprouve entièrement sans réseau.
final class MachineJumelageTests: XCTestCase {

    private func machine() -> MachineJumelage { MachineJumelage(appareil: "iPhone de Chris") }

    // MARK: - Première rencontre

    func testSansJetonOnDemandeUnJumelage() {
        var machine = machine()
        let actions = machine.recevoir(.canalOuvert(jetonConnu: nil))
        XCTAssertEqual(actions, [.emettre(.jumelageDemande(appareil: "iPhone de Chris"))])
        XCTAssertEqual(machine.etape, .demandeEnvoyee)
    }

    func testLeParcoursCompletDuPremierJumelage() {
        var machine = machine()
        _ = machine.recevoir(.canalOuvert(jetonConnu: nil))

        XCTAssertEqual(machine.recevoir(.recu(.jumelageAttente)), [])
        XCTAssertEqual(machine.etape, .codeAttendu(essaisRestants: 3))

        XCTAssertEqual(
            machine.recevoir(.codeSaisi("042195")), [.emettre(.jumelageCode(code: "042195"))]
        )
        XCTAssertEqual(machine.etape, .codeEnVerification)

        // `☠` Après l'acceptation, on enchaîne sur `bonjour` : c'est la seule
        // voie définie vers `bienvenue`, donc vers le nom du PC et ses sources.
        let jeton = String(repeating: "c", count: 32)
        XCTAssertEqual(
            machine.recevoir(.recu(.jumelageAccepte(jeton: jeton))),
            [.conserverJeton(jeton), .emettre(.bonjour(jeton: jeton))]
        )
        XCTAssertEqual(machine.etape, .authentification)

        let sources = [SourceAudio(id: "s1", nom: "Casque", defaut: true)]
        XCTAssertEqual(machine.recevoir(.recu(.bienvenue(nom: "Tour", sources: sources))), [])
        XCTAssertEqual(machine.etape, .liee(nom: "Tour", sources: sources))
        XCTAssertTrue(machine.etablie)
    }

    // MARK: - Rencontres suivantes

    /// Le jeton gardé fait sauter tout le jumelage : c'est la promesse « la
    /// première fois seulement ».
    func testAvecUnJetonOnSauteDirectementAuBonjour() {
        var machine = machine()
        let jeton = String(repeating: "b", count: 32)
        XCTAssertEqual(
            machine.recevoir(.canalOuvert(jetonConnu: jeton)), [.emettre(.bonjour(jeton: jeton))]
        )
        XCTAssertEqual(machine.etape, .authentification)
        _ = machine.recevoir(.recu(.bienvenue(nom: "Tour", sources: [])))
        XCTAssertTrue(machine.etablie)
    }

    func testUnJetonVideCompteCommeAucunJeton() {
        var machine = machine()
        XCTAssertEqual(
            machine.recevoir(.canalOuvert(jetonConnu: "")),
            [.emettre(.jumelageDemande(appareil: "iPhone de Chris"))]
        )
    }

    // MARK: - Les trois essais

    /// `☠` Trois codes faux consécutifs ferment la connexion — le protocole le
    /// dit, et c'est ce qui empêche un voisin de deviner six chiffres.
    func testTroisCodesFauxFermentLaConnexion() {
        var machine = machine()
        _ = machine.recevoir(.canalOuvert(jetonConnu: nil))
        _ = machine.recevoir(.recu(.jumelageAttente))

        for restants in [2, 1] {
            _ = machine.recevoir(.codeSaisi("000000"))
            XCTAssertEqual(machine.recevoir(.recu(.jumelageRefuse(raison: "code faux"))), [])
            XCTAssertEqual(machine.etape, .codeAttendu(essaisRestants: restants))
        }
        _ = machine.recevoir(.codeSaisi("000000"))
        XCTAssertEqual(
            machine.recevoir(.recu(.jumelageRefuse(raison: "code faux"))), [.fermerCanal]
        )
        XCTAssertEqual(machine.etape, .refusee(raison: "code faux"))
    }

    /// Un code mal formé ne part pas et ne coûte PAS un essai : le clavier iOS
    /// glisse volontiers une espace, et Chris n'a pas à payer pour ça.
    func testUnCodeMalFormeNeConsommePasDEssai() {
        var machine = machine()
        _ = machine.recevoir(.canalOuvert(jetonConnu: nil))
        _ = machine.recevoir(.recu(.jumelageAttente))
        XCTAssertEqual(machine.recevoir(.codeSaisi("0421")), [])
        XCTAssertEqual(machine.recevoir(.codeSaisi("")), [])
        XCTAssertEqual(machine.etape, .codeAttendu(essaisRestants: 3))
    }

    /// Les espaces et la ponctuation sautent ; les six chiffres partent.
    func testUnCodeAvecDesEspacesEstNormaliseAvantDePartir() {
        var machine = machine()
        _ = machine.recevoir(.canalOuvert(jetonConnu: nil))
        _ = machine.recevoir(.recu(.jumelageAttente))
        XCTAssertEqual(
            machine.recevoir(.codeSaisi(" 04 21-95 ")), [.emettre(.jumelageCode(code: "042195"))]
        )
    }

    func testUnCodeSaisiHorsEtapeNePartPas() {
        var machine = machine()
        XCTAssertEqual(machine.recevoir(.codeSaisi("042195")), [])
        XCTAssertEqual(machine.etape, .repos)
    }

    // MARK: - Le jeton mort

    /// `☠` Sans cette bascule, un PC réinstallé laisserait l'app coincée sur un
    /// jeton que personne ne reconnaît, sans aucun moyen d'en redemander un.
    func testUnJetonRefuseEstOublieEtOnRejumelle() {
        var machine = machine()
        _ = machine.recevoir(.canalOuvert(jetonConnu: "jeton-perime"))
        XCTAssertEqual(
            machine.recevoir(.recu(.jumelageRefuse(raison: "jeton inconnu"))),
            [.oublierJeton, .emettre(.jumelageDemande(appareil: "iPhone de Chris"))]
        )
        XCTAssertEqual(machine.etape, .demandeEnvoyee)

        // Et le parcours complet redevient possible dans la foulée.
        _ = machine.recevoir(.recu(.jumelageAttente))
        XCTAssertEqual(machine.etape, .codeAttendu(essaisRestants: 3))
    }

    // MARK: - Fermeture

    func testLaFermetureDuCanalSeVoitDansLEtape() {
        var machine = machine()
        _ = machine.recevoir(.canalOuvert(jetonConnu: "j"))
        _ = machine.recevoir(.recu(.bienvenue(nom: "Tour", sources: [])))
        XCTAssertEqual(machine.recevoir(.canalFerme), [])
        XCTAssertEqual(machine.etape, .fermee)
        XCTAssertFalse(machine.etablie)
    }

    /// Un refus définitif survit à la fermeture : c'est le PC qui a coupé, et
    /// Chris doit lire POURQUOI, pas un « connexion fermée » générique.
    func testUnRefusSurvitALaFermetureDuCanal() {
        var machine = machine()
        _ = machine.recevoir(.canalOuvert(jetonConnu: nil))
        _ = machine.recevoir(.recu(.jumelageAttente))
        for _ in 0..<3 {
            _ = machine.recevoir(.codeSaisi("000000"))
            _ = machine.recevoir(.recu(.jumelageRefuse(raison: "code faux")))
        }
        _ = machine.recevoir(.canalFerme)
        XCTAssertEqual(machine.etape, .refusee(raison: "code faux"))
    }

    /// Une reconnexion après trois échecs repart avec trois essais neufs.
    func testUneReconnexionRendLesTroisEssais() {
        var machine = machine()
        _ = machine.recevoir(.canalOuvert(jetonConnu: nil))
        _ = machine.recevoir(.recu(.jumelageAttente))
        _ = machine.recevoir(.codeSaisi("000000"))
        _ = machine.recevoir(.recu(.jumelageRefuse(raison: "code faux")))
        XCTAssertEqual(machine.etape, .codeAttendu(essaisRestants: 2))

        _ = machine.recevoir(.canalFerme)
        _ = machine.recevoir(.canalOuvert(jetonConnu: nil))
        _ = machine.recevoir(.recu(.jumelageAttente))
        XCTAssertEqual(machine.etape, .codeAttendu(essaisRestants: 3))
    }

    /// Le battement et l'état ne bougent jamais l'étape du jumelage.
    func testLeBattementEtLEtatNeChangentRien() {
        var machine = machine()
        _ = machine.recevoir(.canalOuvert(jetonConnu: "j"))
        _ = machine.recevoir(.recu(.bienvenue(nom: "Tour", sources: [])))
        let etat = EtatPoste(
            emission: true, source: "s1", airplay: EtatAirPlay(actif: false, appareil: "")
        )
        XCTAssertEqual(machine.recevoir(.recu(.battement)), [])
        XCTAssertEqual(machine.recevoir(.recu(.etat(etat))), [])
        XCTAssertTrue(machine.etablie)
    }

    // MARK: - Le dépôt de jetons

    func testLeMagasinMemoireConserveEtOublie() {
        let magasin = MagasinJetonsMemoire()
        XCTAssertNil(magasin.jeton(poste: "pc1"))
        magasin.conserver(jeton: "j1", poste: "pc1")
        XCTAssertEqual(magasin.jeton(poste: "pc1"), "j1")
        XCTAssertNil(magasin.jeton(poste: "pc2"), "les postes ne se mélangent pas")
        magasin.oublier(poste: "pc1")
        XCTAssertNil(magasin.jeton(poste: "pc1"))
    }
}
