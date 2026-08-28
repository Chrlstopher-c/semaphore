import Foundation
import Testing

@testable import VigieNoyau

@Suite("Attente d'une réponse de fil")
struct AttenteFilsTests {

    /// Fabrique un lot de fils par le décodeur du contrat : les construire à la
    /// main masquerait une dérive entre le JSON du serveur et le type Swift.
    private func fils(_ entrees: [(id: String, majA: Int, active: Bool)]) throws -> [FilApi] {
        let corps = entrees.map { entree in
            """
            {"id": "\(entree.id)", "titre": "Fil \(entree.id)", "creeA": 1,
             "majA": \(entree.majA), "active": \(entree.active), "contextPct": null,
             "compactions": 0, "model": null, "effort": null, "machine": null,
             "autonomieDebut": null, "autonomieFin": null, "autonomieObjectif": null,
             "plafondAutonomie": "herite"}
            """
        }.joined(separator: ",")
        let charge = Data("""
            {"pcOnline": true, "stale": false, "data": [\(corps)]}
            """.utf8)
        return try #require(DecodeurContrat.lecture([FilApi].self, statut: 200, corps: charge).charge)
    }

    @Test("un fil qui a fini et dont l'horodatage a bougé fait sonner une fois")
    func reponseArrivee() throws {
        var attente = AttenteFils()
        attente.attendre(id: "a", titre: "Chantier", majA: 100, maintenant: 1_000)
        let repondus = attente.repondus(
            try fils([(id: "a", majA: 200, active: false)]), maintenant: 2_000
        )
        #expect(repondus.map(\.id) == ["a"])
        #expect(repondus.first?.titre == "Chantier")
        // Retiré de l'attente : le même fil ne sonne jamais deux fois.
        #expect(attente.vide)
    }

    @Test("un fil qui génère encore ne fait rien sonner")
    func encoreEnCours() throws {
        var attente = AttenteFils()
        attente.attendre(id: "a", titre: "Chantier", majA: 100, maintenant: 1_000)
        let repondus = attente.repondus(
            try fils([(id: "a", majA: 150, active: true)]), maintenant: 2_000
        )
        #expect(repondus.isEmpty)
        #expect(!attente.vide)
    }

    /// `☠` La distinction qui justifie de retenir `majAuDepart` : une génération
    /// interrompue rend le fil inactif SANS rien produire. Sonner « réponse
    /// arrivée » annoncerait alors une réponse qui n'existe pas.
    @Test("une génération coupée sans rien produire ne sonne pas")
    func interruptionSansReponse() throws {
        var attente = AttenteFils()
        attente.attendre(id: "a", titre: "Chantier", majA: 100, maintenant: 1_000)
        let repondus = attente.repondus(
            try fils([(id: "a", majA: 100, active: false)]), maintenant: 2_000
        )
        #expect(repondus.isEmpty)
        #expect(attente.vide)
    }

    @Test("un fil disparu de la liste est oublié sans rien annoncer")
    func filArchive() throws {
        var attente = AttenteFils()
        attente.attendre(id: "disparu", titre: "Archivé", majA: 100, maintenant: 1_000)
        let repondus = attente.repondus(
            try fils([(id: "autre", majA: 200, active: false)]), maintenant: 2_000
        )
        #expect(repondus.isEmpty)
        #expect(attente.vide)
    }

    @Test("une attente périmée cesse sans annoncer une réponse qui n'est jamais venue")
    func peremption() throws {
        var attente = AttenteFils()
        attente.attendre(id: "a", titre: "Chantier", majA: 100, maintenant: 0)
        let repondus = attente.repondus(
            try fils([(id: "a", majA: 100, active: true)]),
            maintenant: AttenteFils.peremptionMs + 1
        )
        #expect(repondus.isEmpty)
        #expect(attente.vide)
    }

    @Test("rouvrir le fil annule l'attente")
    func oubliExplicite() {
        var attente = AttenteFils()
        attente.attendre(id: "a", titre: "Chantier", majA: 100, maintenant: 1_000)
        attente.oublier("a")
        #expect(attente.vide)
    }

    @Test("plusieurs fils attendus sonnent du plus ancien départ au plus récent")
    func ordreDesReponses() throws {
        var attente = AttenteFils()
        attente.attendre(id: "recent", titre: "B", majA: 10, maintenant: 5_000)
        attente.attendre(id: "ancien", titre: "A", majA: 10, maintenant: 1_000)
        let repondus = attente.repondus(
            try fils([(id: "recent", majA: 20, active: false), (id: "ancien", majA: 20, active: false)]),
            maintenant: 6_000
        )
        #expect(repondus.map(\.id) == ["ancien", "recent"])
    }

    /// `☠` La mémoire de veille est relue d'une VERSION à l'autre. Un champ
    /// ajouté ne doit jamais rendre l'ancienne illisible : ce serait re-sonner
    /// tout ce qui attend, au premier lancement suivant chaque mise à jour.
    @Test("une mémoire écrite avant ces champs se relit sans repartir de zéro")
    func memoireAncienne() throws {
        let ancienne = Data("""
            {"faits": {"filigrane": 42, "amorce": true, "vus": {}},
             "mandats": {"vus": ["m1"]}, "rallonges": {"vus": []}}
            """.utf8)
        let memoire = try JSONDecoder().decode(MemoireVeille.self, from: ancienne)
        #expect(memoire.faits.filigrane == 42)
        #expect(memoire.mandats.dejaVu("m1"))
        #expect(memoire.arbitrages.taille == 0)
        #expect(memoire.filsAttendus.vide)
    }
}
