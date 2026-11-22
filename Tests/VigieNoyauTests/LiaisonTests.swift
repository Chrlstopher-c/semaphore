import Foundation
import Testing
@testable import VigieNoyau

@Test func attenteDoubleneBorneeA30() {
    #expect(LiaisonRelais.attenteSuivante(2) == 4)
    #expect(LiaisonRelais.attenteSuivante(4) == 8)
    #expect(LiaisonRelais.attenteSuivante(16) == 30)
    #expect(LiaisonRelais.attenteSuivante(30) == 30)
}

@Test func adresseFluxPasseEnWsOuWss() throws {
    let clair = try #require(LiaisonRelais.adresseFlux(URL(string: "http://relais.example.com:8080")!))
    #expect(clair.absoluteString == "ws://relais.example.com:8080")
    let chiffre = try #require(LiaisonRelais.adresseFlux(URL(string: "https://relais.example.com")!))
    #expect(chiffre.scheme == "wss")
    #expect(LiaisonRelais.adresseFlux(URL(string: "ftp://relais.example.com")!) == nil)
}

@Test func etatEtAttenteDemandentLesArchivees() {
    #expect(LiaisonRelais.etatAvecArchivees() == "/api/etat?archivees=1")
    #expect(LiaisonRelais.attenteAvecArchivees(version: 4, notifications: 9).hasSuffix("&archivees=1"))
}
