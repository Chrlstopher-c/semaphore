import Foundation
import Testing
@testable import VigieNoyau

private func notif(_ seq: Int) -> NotificationRelais {
    NotificationRelais(seq: seq, sessionId: nil, niveau: .info, titre: "T", texte: "", ts: "", lue: false)
}

@Test func notificationsNouvellesEnTeteSansDoublon() {
    let existantes = [notif(3), notif(2), notif(1)]
    let fusion = MiseAJourParc.notifications([notif(4), notif(2)], dans: existantes)
    #expect(fusion.map(\.seq) == [4, 3, 2, 1])
}

@Test func notificationsBornees() {
    let beaucoup = (1...(MiseAJourParc.tailleMaxNotifications + 5)).map { notif($0) }
    let fusion = MiseAJourParc.notifications(beaucoup, dans: [])
    #expect(fusion.count == MiseAJourParc.tailleMaxNotifications)
    #expect(fusion.first?.seq == MiseAJourParc.tailleMaxNotifications + 5)
}
