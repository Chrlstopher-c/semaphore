import Testing
@testable import VigieNoyau

// Le choix du nœud d'un appareil : un nœud en ligne, jamais soi, jamais un autre appareil.

struct SelectionNoeudTests {
    private let moi = "aaaaaaaaaaaa"

    @Test func choisitLePremierNoeudEnLigne() {
        let membres: [ProtocoleAiguilleur.Membre] = [
            .init(id: moi, enLigne: true, genre: "appareil"),
            .init(id: "bbbbbbbbbbbb", enLigne: false, genre: "noeud"),
            .init(id: "cccccccccccc", enLigne: true, genre: "appareil"),
            .init(id: "dddddddddddd", enLigne: true, genre: "noeud"),
            .init(id: "eeeeeeeeeeee", enLigne: true, genre: "noeud"),
        ]
        #expect(SelectionNoeud.choisir(membres, moi: moi) == "dddddddddddd")
    }

    @Test func aucunNoeudEnLigneDonneNil() {
        let membres: [ProtocoleAiguilleur.Membre] = [
            .init(id: moi, enLigne: true, genre: "appareil"),
            .init(id: "bbbbbbbbbbbb", enLigne: false, genre: "noeud"),
        ]
        #expect(SelectionNoeud.choisir(membres, moi: moi) == nil)
    }

    @Test func genreAbsentNestPasUnNoeud() {
        let membres: [ProtocoleAiguilleur.Membre] = [.init(id: "bbbbbbbbbbbb", enLigne: true)]
        #expect(SelectionNoeud.choisir(membres, moi: moi) == nil)
    }
}
