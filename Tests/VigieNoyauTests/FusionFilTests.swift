import Foundation
import Testing
@testable import VigieNoyau

private func evt(_ seq: Int) -> EvenementDate {
    EvenementDate(seq: seq, sessionId: "s", ts: "2026-11-22T08:00:00.000Z", evt: .texte(texte: "\(seq)", agent: nil))
}

@Test func ajouterNeRetientQueLesSeqPlusRecents() {
    let fil = [evt(1), evt(2)]
    #expect(FusionFil.ajouter(evt(3), au: fil).map(\.seq) == [1, 2, 3])
    #expect(FusionFil.ajouter(evt(2), au: fil).map(\.seq) == [1, 2], "un seq déjà vu ne se répète pas")
    #expect(FusionFil.ajouter(evt(7), au: []).map(\.seq) == [7])
}

@Test func fusionnerTrieEtSupprimeLesDoublons() {
    let fusion = FusionFil.fusionner([evt(3), evt(4)], [evt(1), evt(3), evt(5)])
    #expect(fusion.map(\.seq) == [1, 3, 4, 5])
}

@Test func fusionnerGardeLaPremiereOccurrence() {
    let original = EvenementDate(seq: 2, sessionId: "s", ts: "", evt: .texte(texte: "premier", agent: nil))
    let doublon = EvenementDate(seq: 2, sessionId: "s", ts: "", evt: .texte(texte: "second", agent: nil))
    #expect(FusionFil.fusionner([original], [doublon]) == [original])
}
