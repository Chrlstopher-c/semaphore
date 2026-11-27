import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Projets de l'agent")
struct ProjetsTests {
    @Test func nomsAcceptesParLeServeur() {
        #expect(DepotProjets.nomValide("site-vitrine_2.0"))
        #expect(!DepotProjets.nomValide("Site"))
        #expect(!DepotProjets.nomValide("-site"))
        #expect(!DepotProjets.nomValide(String(repeating: "a", count: 64)))
    }

    @Test func cheminEncodeDansLaRequete() {
        #expect(DepotProjets.encoder("src/mon fichier&.py") == "src%2Fmon%20fichier%26.py")
        let url = ClientEchoHub.url(base: URL(string: "https://relais.example")!,
                                    chemin: "projets/p/fichier?chemin=\(DepotProjets.encoder("a/b c"))")
        #expect(url?.absoluteString == "https://relais.example/api/projets/p/fichier?chemin=a%2Fb%20c")
    }

    @Test func decodeLesReponses() throws {
        let d = CodageJSON.decodeur()
        let catalogue = try d.decode(CatalogueProjets.self, from: Data(#"{"actif":true,"racine":"/r","projets":[{"nom":"site","modifie_le":1764320000.5,"instantanes":true}]}"#.utf8))
        #expect(catalogue.projets.first?.instantanes == true)
        let modifs = try d.decode(ModificationsProjet.self, from: Data(#"{"reference":{"sha":"abc","date":1764320000,"message":"m"},"fichiers":[{"chemin":"a.py","etat":"M","ajouts":3,"suppressions":null}]}"#.utf8))
        #expect(modifs.fichiers.first?.ajouts == 3)
        let fichier = try d.decode(ContenuFichier.self, from: Data(#"{"chemin":"img.png","taille":10,"contenu":null,"binaire":true,"tronque":false}"#.utf8))
        #expect(fichier.binaire && fichier.contenu == nil)
    }
}
