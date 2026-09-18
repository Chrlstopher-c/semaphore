import XCTest
@testable import DuplexNoyau

/// Le canal de contrôle : ces messages sont la seule voix entre l'iPhone et le
/// PC. Leur forme est fixée par `PROTOCOLE.md` ; un `type` mal écrit ne lève
/// aucune erreur — il est ignoré en silence, et rien ne démarre.
final class MessageControleTests: XCTestCase {

    private func objet(_ message: MessageTelephone) throws -> [String: Any] {
        let donnees = try JSONEncoder().encode(message)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: donnees) as? [String: Any])
    }

    // MARK: - Téléphone → PC

    func testJumelageDemandePorteLeNomDeLAppareil() throws {
        let objet = try objet(.jumelageDemande(appareil: "iPhone de Chris"))
        XCTAssertEqual(objet["type"] as? String, "jumelage.demande")
        XCTAssertEqual(objet["appareil"] as? String, "iPhone de Chris")
    }

    func testJumelageCodePorteLeCode() throws {
        let objet = try objet(.jumelageCode(code: "042195"))
        XCTAssertEqual(objet["type"] as? String, "jumelage.code")
        XCTAssertEqual(objet["code"] as? String, "042195")
    }

    func testBonjourPorteLeJeton() throws {
        let objet = try objet(.bonjour(jeton: String(repeating: "a", count: 32)))
        XCTAssertEqual(objet["type"] as? String, "bonjour")
        XCTAssertEqual((objet["jeton"] as? String)?.count, 32)
    }

    /// `☠` Le port annoncé est celui que le téléphone écoute DÉJÀ. C'est la clé
    /// du sens PC → téléphone : le PC émet vers l'adresse d'où vient la
    /// connexion de contrôle, sur ce port-là.
    func testFluxDemarrerPorteLePortUDP() throws {
        let objet = try objet(.fluxDemarrer(port: 51_820))
        XCTAssertEqual(objet["type"] as? String, "flux.demarrer")
        XCTAssertEqual(objet["port"] as? Int, 51_820)
    }

    func testLesMessagesNusNePortentQueLeurType() throws {
        for (message, type) in [
            (MessageTelephone.fluxArreter, "flux.arreter"),
            (MessageTelephone.battement, "battement"),
        ] {
            let objet = try objet(message)
            XCTAssertEqual(objet["type"] as? String, type)
            XCTAssertEqual(objet.count, 1, "\(type) ne doit rien porter d'autre")
        }
    }

    func testSourceChoisirPorteLId() throws {
        let objet = try objet(.sourceChoisir(id: "sortie-casque"))
        XCTAssertEqual(objet["type"] as? String, "source.choisir")
        XCTAssertEqual(objet["id"] as? String, "sortie-casque")
    }

    // MARK: - PC → téléphone

    func testJumelageAttenteSeDecode() {
        XCTAssertEqual(
            MessagePoste.decoder(texte: #"{"type":"jumelage.attente"}"#), .jumelageAttente
        )
    }

    func testJumelageAccepteRendLeJeton() {
        let jeton = String(repeating: "f", count: 32)
        XCTAssertEqual(
            MessagePoste.decoder(texte: #"{"type":"jumelage.accepte","jeton":"\#(jeton)"}"#),
            .jumelageAccepte(jeton: jeton)
        )
    }

    func testJumelageRefuseRendLaRaison() {
        XCTAssertEqual(
            MessagePoste.decoder(texte: #"{"type":"jumelage.refuse","raison":"code faux"}"#),
            .jumelageRefuse(raison: "code faux")
        )
    }

    func testBienvenueRendLeNomEtLesSources() throws {
        let json = """
        {"type":"bienvenue","nom":"Tour Arch","sources":[
          {"id":"sortie-1","nom":"Casque","defaut":true},
          {"id":"sortie-2","nom":"Enceintes","defaut":false}]}
        """
        guard case let .bienvenue(nom, sources) = try XCTUnwrap(MessagePoste.decoder(texte: json))
        else { return XCTFail("attendu bienvenue") }
        XCTAssertEqual(nom, "Tour Arch")
        XCTAssertEqual(sources.map(\.id), ["sortie-1", "sortie-2"])
        XCTAssertTrue(sources[0].defaut)
        XCTAssertFalse(sources[1].defaut)
    }

    /// Un PC sans sortie captable reste joignable : on n'exige pas la clé.
    func testBienvenueSansSourcesResteLisible() {
        XCTAssertEqual(
            MessagePoste.decoder(texte: #"{"type":"bienvenue","nom":"Tour"}"#),
            .bienvenue(nom: "Tour", sources: [])
        )
    }

    func testEtatRendLEmissionLaSourceEtAirPlay() throws {
        let json = """
        {"type":"etat","emission":true,"source":"sortie-1",
         "airplay":{"actif":true,"appareil":"HomePod"}}
        """
        guard case let .etat(etat) = try XCTUnwrap(MessagePoste.decoder(texte: json))
        else { return XCTFail("attendu etat") }
        XCTAssertTrue(etat.emission)
        XCTAssertEqual(etat.source, "sortie-1")
        XCTAssertEqual(etat.airplay, EtatAirPlay(actif: true, appareil: "HomePod"))
    }

    /// `☠` Un type inconnu ne fait pas tomber la réception : le PC peut gagner
    /// un message qu'une IPA vieille d'une semaine ne connaît pas.
    func testUnTypeInconnuRendNil() {
        XCTAssertNil(MessagePoste.decoder(texte: #"{"type":"licorne"}"#))
    }

    func testUnChampObligatoireManquantRendNil() {
        XCTAssertNil(MessagePoste.decoder(texte: #"{"type":"jumelage.accepte"}"#))
    }

    // MARK: - Les constantes du protocole

    func testLesConstantesSontCellesDuProtocole() {
        XCTAssertEqual(Cadence.portControle, 7_651)
        XCTAssertEqual(Cadence.service, "_duplex._tcp")
        XCTAssertEqual(Cadence.battementSecondes, 5)
        XCTAssertEqual(Cadence.silenceToleredSecondes, 15)
        XCTAssertEqual(Cadence.codeSecondes, 120)
        XCTAssertEqual(Cadence.longueurCode, 6)
    }

    // MARK: - L'enregistrement mDNS

    func testUnTXTCompletDonneUnPoste() {
        let poste = EnregistrementTXT.lire(
            ["v": "1", "nom": "Tour Arch", "id": "A1B2C3D4E5F60718"], service: "duplex-pc"
        )
        XCTAssertEqual(poste?.id, "a1b2c3d4e5f60718")
        XCTAssertEqual(poste?.nom, "Tour Arch")
        XCTAssertEqual(poste?.service, "duplex-pc")
    }

    /// `☠` Sans `id` stable, impossible de retrouver le jeton du jumelage
    /// précédent : Chris retaperait un code à chaque bail DHCP. On ignore le
    /// service plutôt que de l'afficher cassé.
    func testUnTXTSansIdUtilisableEstIgnore() {
        XCTAssertNil(EnregistrementTXT.lire(["v": "1", "nom": "Tour"], service: "s"))
        XCTAssertNil(EnregistrementTXT.lire(["v": "1", "id": "trop-court"], service: "s"))
        XCTAssertNil(
            EnregistrementTXT.lire(["v": "1", "id": "ZZZZZZZZZZZZZZZZ"], service: "s")
        )
    }

    func testUneVersionDeProtocoleInconnueEstIgnoree() {
        XCTAssertNil(
            EnregistrementTXT.lire(["v": "2", "id": "a1b2c3d4e5f60718"], service: "s")
        )
    }

    func testSansNomLisibleOnRetombeSurLeNomDeService() {
        let poste = EnregistrementTXT.lire(
            ["v": "1", "nom": "", "id": "a1b2c3d4e5f60718"], service: "duplex-pc"
        )
        XCTAssertEqual(poste?.nom, "duplex-pc")
    }
}
