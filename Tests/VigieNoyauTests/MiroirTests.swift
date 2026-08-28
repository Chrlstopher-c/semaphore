import Foundation
import Testing
@testable import VigieNoyau

@Suite("Miroir — l'état local persistant")
struct MiroirTests {

    private func enveloppe(_ charge: String, pcOnline: Bool = true, stale: Bool = false) -> Data {
        Data("""
        {"pcOnline":\(pcOnline),"stale":\(stale),"data":\(charge),"message":null}
        """.utf8)
    }

    @Test("un relevé enveloppé se relit avec sa date et son verdict sur le PC")
    func relectureEnveloppe() throws {
        var miroir = Instantane()
        let quand = Date(timeIntervalSince1970: 1_700_000_000)
        miroir.deposer(.machines, corps: enveloppe("[\"pi\",\"vps\"]"),
                       forme: .enveloppe, pcEnLigne: true, releveA: quand)
        let relu = try #require(miroir.lire([String].self, .machines))
        #expect(relu.valeur == ["pi", "vps"])
        #expect(relu.releveA == quand)
        #expect(relu.pcEnLigne)
    }

    @Test("une réponse hors enveloppe se relit par le décodeur nu")
    func relectureNue() throws {
        var miroir = Instantane()
        miroir.deposer(.sante, corps: Data("{\"ok\":true,\"pcOnline\":false}".utf8),
                       forme: .nue, pcEnLigne: false)
        let relu = try #require(miroir.lire(SanteApi.self, .sante))
        #expect(relu.valeur.ok)
        #expect(relu.valeur.pcOnline == false)
    }

    @Test("chaque section porte SA date, pas une date globale")
    func datesIndependantes() throws {
        var miroir = Instantane()
        let vieux = Date(timeIntervalSince1970: 1_700_000_000)
        let recent = vieux.addingTimeInterval(3600)
        miroir.deposer(.machines, corps: enveloppe("[]"), forme: .enveloppe, pcEnLigne: true, releveA: vieux)
        miroir.deposer(.missions, corps: enveloppe("[]"), forme: .enveloppe, pcEnLigne: true, releveA: recent)
        #expect(miroir.releveA(.machines) == vieux)
        #expect(miroir.releveA(.missions) == recent)
    }

    @Test("deux fils différents ne s'écrasent pas")
    func precisionSepareLesCles() throws {
        var miroir = Instantane()
        miroir.deposer(.fil("c-1"), corps: enveloppe("\"un\""), forme: .enveloppe, pcEnLigne: true)
        miroir.deposer(.fil("c-2"), corps: enveloppe("\"deux\""), forme: .enveloppe, pcEnLigne: true)
        #expect(miroir.lire(String.self, .fil("c-1"))?.valeur == "un")
        #expect(miroir.lire(String.self, .fil("c-2"))?.valeur == "deux")
    }

    @Test("un corps devenu illisible pour le contrat ne rend rien, et ne plante pas")
    func corpsIllisible() {
        var miroir = Instantane()
        Trace.seuil = .muet
        defer { Trace.seuil = .info }
        miroir.deposer(.missions, corps: enveloppe("{\"pasUneListe\":1}"), forme: .enveloppe, pcEnLigne: true)
        #expect(miroir.lire([MissionApi].self, .missions) == nil)
    }

    @Test("une section trop lourde est refusée, jamais tronquée")
    func poidsPlafonne() {
        var miroir = Instantane()
        Trace.seuil = .muet
        defer { Trace.seuil = .info }
        let enorme = Data(repeating: 0x20, count: Instantane.poidsMaxSection + 1)
        miroir.deposer(.missions, corps: enorme, forme: .enveloppe, pcEnLigne: true)
        #expect(miroir.section(.missions) == nil)
    }

    @Test("le miroir s'élague aux sections les plus récentes")
    func elagage() {
        var miroir = Instantane()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for rang in 0..<(Instantane.sectionsMax + 10) {
            miroir.deposer(.fil("c-\(rang)"), corps: enveloppe("\"x\""), forme: .enveloppe,
                           pcEnLigne: true, releveA: base.addingTimeInterval(Double(rang)))
        }
        #expect(miroir.rubriquesConnues == Instantane.sectionsMax)
        #expect(miroir.section(.fil("c-0")) == nil)
        #expect(miroir.section(.fil("c-\(Instantane.sectionsMax + 9)")) != nil)
    }

    @Test("l'instantané traverse un aller-retour JSON sans perdre ses sections")
    func persistance() throws {
        var miroir = Instantane()
        miroir.deposer(.comptes, corps: enveloppe("[]"), forme: .enveloppe, pcEnLigne: false)
        let octets = try JSONEncoder().encode(miroir)
        let relu = try JSONDecoder().decode(Instantane.self, from: octets)
        #expect(relu.version == Instantane.versionCourante)
        #expect(relu.lire([String].self, .comptes)?.pcEnLigne == false)
    }

    @Test("le dépôt écrit puis relit sur disque")
    func depotSurDisque() async throws {
        let fichier = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vigie-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fichier) }

        let depot = DepotMiroir(fichier: fichier)
        await depot.charger()
        await depot.deposer(.modeles, corps: enveloppe("[\"opus\"]"), forme: .enveloppe, pcEnLigne: true)
        await depot.ecrireMaintenant()

        let relu = DepotMiroir(fichier: fichier)
        await relu.charger()
        let donnee = try #require(await relu.lire([String].self, .modeles))
        #expect(donnee.valeur == ["opus"])
    }
}
