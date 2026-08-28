import Foundation
import Testing

@testable import VigieNoyau

@Suite("Machines — santé, mesures différentielles et mise en forme")
struct MachinesTests {

    private func metriques(
        cpu: Int? = 12,
        memPct: Int? = 40,
        memUtiliseeMo: Int? = 12_800,
        memTotaleMo: Int? = 32_000,
        disqueUtilise: Double? = 400,
        disqueTotal: Double? = 916,
        temp: Int? = 52,
        uptime: Int = 3600,
        montant: Double? = 12.5,
        descendant: Double? = 340.0,
        gpu: MetriquesGpu? = nil
    ) throws -> MetriquesHote {
        let corps = Data(
            """
            {"machine": "trinityarch", "cpuPct": \(json(cpu)), "memUtiliseeMo": \(json(memUtiliseeMo)),
             "memTotaleMo": \(json(memTotaleMo)), "memPct": \(json(memPct)),
             "disqueUtiliseGo": \(json(disqueUtilise)), "disqueTotalGo": \(json(disqueTotal)),
             "tempCpuC": \(json(temp)), "uptimeS": \(uptime),
             "reseauMontantKo": \(json(montant)), "reseauDescendantKo": \(json(descendant)),
             "gpu": \(gpu == nil ? "null" : "{\"utilPct\": 44, \"memUtiliseeMo\": 2048, \"memTotaleMo\": 8192, \"tempC\": 61}"),
             "releveA": 1750000000000}
            """.utf8
        )
        return try JSONDecoder().decode(MetriquesHote.self, from: corps)
    }

    private func json(_ valeur: Int?) -> String { valeur.map { "\($0)" } ?? "null" }
    private func json(_ valeur: Double?) -> String { valeur.map { "\($0)" } ?? "null" }

    // MARK: - Le premier relevé n'est pas une panne

    @Test("processeur et réseau nuls au premier relevé : en cours de mesure, pas absents")
    func premierReleve() throws {
        let brut = try metriques(cpu: nil, montant: nil, descendant: nil)
        #expect(brut.chargeProcesseur == .enCoursDeMesure)
        #expect(brut.debitMontant.enAttente)
        #expect(brut.debitDescendant.enAttente)
        // Les grandeurs lues directement, elles, sont bien là dès le premier passage.
        #expect(brut.memPct == 40)
        #expect(brut.uptimeS == 3600)
    }

    @Test("une valeur mesurée traverse la mesure différentielle sans se perdre")
    func mesureDifferentielle() throws {
        let brut = try metriques(cpu: 87)
        #expect(brut.chargeProcesseur == .mesuree(87))
        #expect(brut.chargeProcesseur.valeur == 87)
        #expect(!brut.chargeProcesseur.enAttente)
    }

    // MARK: - Santé

    @Test("machine éteinte : hors ligne, jamais en danger")
    func horsLigne() throws {
        #expect(SanteMachine.degre(enLigne: false, metriques: nil) == .horsLigne)
        // Même avec un relevé daté en poche : le lien est ce qui tranche.
        #expect(SanteMachine.degre(enLigne: false, metriques: try metriques()) == .horsLigne)
        #expect(SanteMachine.motif(enLigne: false, metriques: nil) == nil)
    }

    @Test("machine rattachée sans relevé : dit que c'est la mesure qui manque")
    func sansReleve() {
        #expect(SanteMachine.degre(enLigne: true, metriques: nil) == .sansReleve)
        #expect(SanteMachine.motif(enLigne: true, metriques: nil)?.contains("relevé") == true)
    }

    @Test("un processeur à 100 % n'est pas une alerte : c'est une machine qui travaille")
    func processeurSatureNestPasUneAlerte() throws {
        let brut = try metriques(cpu: 100, memPct: 40, temp: 52)
        #expect(SanteMachine.degre(enLigne: true, metriques: brut) == .sain)
        #expect(SanteMachine.motif(enLigne: true, metriques: brut) == nil)
    }

    @Test("disque, mémoire et chaleur font basculer, chacun à son seuil")
    func seuils() throws {
        let disquePlein = try metriques(disqueUtilise: 880, disqueTotal: 916)
        #expect(SanteMachine.degre(enLigne: true, metriques: disquePlein) == .danger)
        let disqueTendu = try metriques(disqueUtilise: 760, disqueTotal: 916)
        #expect(SanteMachine.degre(enLigne: true, metriques: disqueTendu) == .vigilance)
        let memoireTendue = try metriques(memPct: 88)
        #expect(SanteMachine.degre(enLigne: true, metriques: memoireTendue) == .vigilance)
        let brulante = try metriques(temp: 91)
        #expect(SanteMachine.degre(enLigne: true, metriques: brulante) == .danger)
    }

    @Test("le motif nomme ce qui a basculé, et rien d'autre")
    func motif() throws {
        let tendue = try metriques(memPct: 90, temp: 78)
        let motif = try #require(SanteMachine.motif(enLigne: true, metriques: tendue))
        #expect(motif.contains("mémoire à 90 %"))
        #expect(motif.contains("processeur à 78 °C"))
        #expect(!motif.contains("disque"))
    }

    @Test("un capteur absent ne fait basculer personne")
    func capteurAbsent() throws {
        let virtuelle = try metriques(memPct: nil, disqueUtilise: nil, disqueTotal: nil, temp: nil)
        #expect(SanteMachine.degre(enLigne: true, metriques: virtuelle) == .sain)
        #expect(virtuelle.partDisque == nil)
        #expect(virtuelle.partMemoire == nil)
    }

    // MARK: - Mise en forme

    @Test("les durées se lisent en jours, heures ou minutes selon l'échelle")
    func durees() {
        #expect(FormatMachine.duree(0) == "—")
        #expect(FormatMachine.duree(300) == "5 min")
        #expect(FormatMachine.duree(3600 * 5 + 720) == "5 h 12 min")
        #expect(FormatMachine.duree(86_400 * 3 + 3600 * 4) == "3 j 4 h")
    }

    @Test("les capacités passent en gigaoctets, virgule française")
    func capacites() {
        // 31,25 tombe pile entre deux décimales : `%.1f` arrondit au pair (IEEE),
        // donc « 31,2 » — même valeur sur l'appareil que sur Arch.
        #expect(FormatMachine.memoire(utiliseeMo: 12_800, totaleMo: 32_000) == "12,5 / 31,2 Go")
        #expect(FormatMachine.memoire(utiliseeMo: nil, totaleMo: 32_000) == "—")
        #expect(FormatMachine.memoire(utiliseeMo: 12_800, totaleMo: 0) == "—")
        #expect(FormatMachine.disque(utiliseGo: 411.6, totalGo: 916.2) == "412 / 916 Go")
        #expect(FormatMachine.memoireGpu(utiliseeMo: 2048, totaleMo: 8192) == "2048 / 8192 Mo")
    }

    @Test("un gros débit bascule en Mo/s plutôt que d'aligner cinq chiffres")
    func debits() {
        #expect(FormatMachine.debit(12.47) == "12,5 Ko/s")
        #expect(FormatMachine.debit(84_213.7) == "82,2 Mo/s")
        #expect(FormatMachine.debit(-3) == "0,0 Ko/s")
    }

    @Test("une grandeur non mesurée s'écrit d'un tiret, jamais d'un zéro")
    func absences() {
        #expect(FormatMachine.pourcentage(nil) == "—")
        #expect(FormatMachine.temperature(nil) == "—")
        #expect(FormatMachine.pourcentage(0) == "0 %")
    }
}
