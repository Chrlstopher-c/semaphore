import Foundation
import Testing
@testable import VigieNoyau

// Les graines d'identité : ce que l'appli stocke. Leur identité publique doit s'exporter et se relire à l'identique.

struct GrainesIdentiteTests {
    @Test func identiteGenereeSExporteEtSeRelitALIdentique() throws {
        let identite = try GrainesIdentite.generer().identite()
        let texte = Chiffrement.Identites.exporter(identite.publique)
        #expect(texte.count == 86)
        #expect(try Chiffrement.Identites.importer(texte) == identite.publique)
    }

    @Test func memesGrainesDonnentMemeEmpreinteAuFormatDeLAppairage() {
        let graines = GrainesIdentite(dh: Data(repeating: 7, count: 32), signature: Data(repeating: 9, count: 32))
        let meme = GrainesIdentite(dh: Data(repeating: 7, count: 32), signature: Data(repeating: 9, count: 32))
        #expect(graines.empreinte == meme.empreinte)
        #expect(graines.empreinte.range(of: "^([0-9A-F]{4} ){15}[0-9A-F]{4}$", options: .regularExpression) != nil)
    }

    @Test func generationDonneDesGrainesNeuves() {
        #expect(GrainesIdentite.generer() != GrainesIdentite.generer())
    }

    @Test func grainesSeLisentEnJSONAllerRetour() throws {
        let graines = GrainesIdentite.generer()
        let octets = try JSONEncoder().encode(graines)
        #expect(try JSONDecoder().decode(GrainesIdentite.self, from: octets) == graines)
    }
}
