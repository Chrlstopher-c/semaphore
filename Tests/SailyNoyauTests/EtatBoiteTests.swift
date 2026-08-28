import XCTest
@testable import SailyNoyau

/// `EtatBoite` est le cœur du monde Saily : la seule logique éprouvable sans
/// réseau ni appareil. Snapshot, dédup par id/updatedAt, filtrage des pierres
/// tombales, tri des épingles, file offline — tout se joue ici.
final class EtatBoiteTests: XCTestCase {

    private func item(
        _ id: String, updatedAt: Int, pinned: Bool = false, deletedAt: Int? = nil,
        tags: [String] = []
    ) -> Item {
        Item(
            id: id, kind: .note, text: id, url: nil, blob: nil, mime: nil, tags: tags,
            pinned: pinned, createdAt: 1, updatedAt: updatedAt, deletedAt: deletedAt
        )
    }

    func testUnSnapshotPeupleEtAvanceLeSince() {
        var etat = EtatBoite()
        etat.appliquer(snapshot: [item("a", updatedAt: 5), item("b", updatedAt: 8)])
        XCTAssertEqual(etat.visibles.count, 2)
        XCTAssertEqual(etat.since, 8)
    }

    /// `☠` Idempotence : un upsert d'`updatedAt` ÉGAL ou INFÉRIEUR ne remplace
    /// rien. C'est ce qui rend le rejeu de la file offline et l'écho du socket
    /// sans effet.
    func testUnUpsertPlusAncienEstIgnore() {
        var etat = EtatBoite()
        etat.appliquer(item: item("a", updatedAt: 10, tags: ["neuf"]))
        etat.appliquer(item: item("a", updatedAt: 4, tags: ["vieux"]))
        XCTAssertEqual(etat.parId["a"]?.tags, ["neuf"])
        etat.appliquer(item: item("a", updatedAt: 10, tags: ["egal"]))
        XCTAssertEqual(etat.parId["a"]?.tags, ["neuf"], "l'égalité laisse l'existant")
    }

    func testUnUpsertPlusRecentRemplace() {
        var etat = EtatBoite()
        etat.appliquer(item: item("a", updatedAt: 4, tags: ["vieux"]))
        etat.appliquer(item: item("a", updatedAt: 12, tags: ["neuf"]))
        XCTAssertEqual(etat.parId["a"]?.tags, ["neuf"])
        XCTAssertEqual(etat.since, 12)
    }

    func testLesPierresTombalesSortentDesVisibles() {
        var etat = EtatBoite()
        etat.appliquer(snapshot: [item("a", updatedAt: 5), item("b", updatedAt: 6, deletedAt: 6)])
        XCTAssertEqual(etat.visibles.map(\.id), ["a"])
        XCTAssertEqual(etat.since, 6, "la tombale compte pour le since")
    }

    func testUneSuppressionCacheUnItemConnu() {
        var etat = EtatBoite()
        etat.appliquer(item: item("a", updatedAt: 5))
        etat.appliquerSuppression(id: "a", deletedAt: 20)
        XCTAssertTrue(etat.visibles.isEmpty)
        XCTAssertEqual(etat.since, 20)
        XCTAssertNotNil(etat.parId["a"], "la tombale reste connue")
    }

    /// Une suppression pour un id jamais vu synthétise une tombale, pour qu'un
    /// snapshot ultérieur ne le ressuscite pas et que le since avance.
    func testUneSuppressionInconnueSynthetiseUneTombale() {
        var etat = EtatBoite()
        etat.appliquerSuppression(id: "fantome", deletedAt: 15)
        XCTAssertEqual(etat.since, 15)
        XCTAssertFalse(etat.parId["fantome"]?.vivant ?? true)
    }

    func testLesEpinglesRemontentEnTete() {
        var etat = EtatBoite()
        etat.appliquer(snapshot: [
            item("recent", updatedAt: 100),
            item("epingle", updatedAt: 5, pinned: true),
            item("vieux", updatedAt: 3),
        ])
        XCTAssertEqual(etat.visibles.map(\.id), ["epingle", "recent", "vieux"])
    }

    func testLesTagsSontCollectesTriesEtSansTombales() {
        var etat = EtatBoite()
        etat.appliquer(snapshot: [
            item("a", updatedAt: 1, tags: ["z", "a"]),
            item("b", updatedAt: 2, deletedAt: 2, tags: ["mort"]),
        ])
        XCTAssertEqual(etat.tags, ["a", "z"])
    }

    // MARK: - Écho et file offline

    func testLEchoDeSesPropresEcrituresEstIgnore() {
        var etat = EtatBoite()
        let msg = MessageServeur.upsert(item: item("a", updatedAt: 5), origin: "ios-moi")
        let change = etat.appliquer(msg, clientId: "ios-moi")
        XCTAssertFalse(change)
        XCTAssertTrue(etat.visibles.isEmpty, "rien appliqué : c'était mon propre écho")
    }

    func testUnUpsertDUnAutreClientEstApplique() {
        var etat = EtatBoite()
        let msg = MessageServeur.upsert(item: item("a", updatedAt: 5), origin: "pc")
        XCTAssertTrue(etat.appliquer(msg, clientId: "ios-moi"))
        XCTAssertEqual(etat.visibles.map(\.id), ["a"])
    }

    func testLaFileOfflineSeRemplitEtSeVideDansLOrdre() {
        var etat = EtatBoite()
        etat.enfiler(.upsert(item: ItemInput(id: "1", kind: .note, text: "un"), clientId: "c"))
        etat.enfiler(.delete(id: "2", clientId: "c"))
        XCTAssertEqual(etat.enAttente.count, 2)
        let vidée = etat.viderFile()
        XCTAssertEqual(vidée.count, 2)
        XCTAssertTrue(etat.enAttente.isEmpty)
        if case .upsert = vidée[0] {} else { XCTFail("ordre non préservé") }
    }

    /// `☠` La file est bornée : au-delà du plafond, la plus ancienne cède. On
    /// vérifie que seules les dernières survivent.
    func testLaFileOfflineEstBornee() {
        var etat = EtatBoite()
        let total = EtatBoite.plafondFile + 5
        for index in 0..<total {
            etat.enfiler(.delete(id: "\(index)", clientId: "c"))
        }
        XCTAssertEqual(etat.enAttente.count, EtatBoite.plafondFile)
        guard case let .delete(id, _) = etat.enAttente.last else { return XCTFail() }
        XCTAssertEqual(id, "\(total - 1)", "la plus récente est gardée")
    }

    func testLOptimismeLocalRendUnItemVisibleAvantLeServeur() {
        var etat = EtatBoite()
        etat.poserLocalement(ItemInput(id: "x", kind: .note, text: "vite"), maintenant: 50)
        XCTAssertEqual(etat.visibles.map(\.id), ["x"])
        XCTAssertEqual(etat.since, 50)
    }
}
