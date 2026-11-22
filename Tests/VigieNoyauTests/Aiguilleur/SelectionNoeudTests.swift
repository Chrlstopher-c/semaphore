import Testing
@testable import VigieNoyau

// Le choix du nœud d'un appareil : préféré s'il est en ligne ; sinon appairé en ligne (sans écran d'abord) ;
// sans appairage, premier nœud avec écran. Jamais soi, jamais un appareil, jamais un nœud refusé.

struct SelectionNoeudTests {
    private let moi = "aaaaaaaaaaaa"
    private let portable = "bbbbbbbbbbbb"
    private let tour = "cccccccccccc"

    private func membre(_ id: String, enLigne: Bool = true, sansEcran: Bool? = nil, genre: String? = "noeud") -> ProtocoleAiguilleur.Membre {
        .init(id: id, enLigne: enLigne, genre: genre, sansEcran: sansEcran)
    }

    @Test func prefereEnLigneGagneSurTout() {
        let membres = [membre(portable), membre(tour, sansEcran: true)]
        #expect(SelectionNoeud.choisir(membres, moi: moi, appaires: [portable, tour], prefere: portable) == portable)
        #expect(SelectionNoeud.choisir(membres, moi: moi, appaires: [portable, tour], prefere: tour) == tour)
    }

    @Test func prefereHorsLigneTombeSurLesAppaires() {
        let membres = [membre(portable), membre(tour, enLigne: false, sansEcran: true)]
        #expect(SelectionNoeud.choisir(membres, moi: moi, appaires: [portable, tour], prefere: tour) == portable)
    }

    @Test func parmiLesAppairesLeSansEcranPasse() {
        let membres = [membre(portable), membre(tour, sansEcran: true)]
        #expect(SelectionNoeud.choisir(membres, moi: moi, appaires: [portable, tour], prefere: nil) == tour)
    }

    @Test func sansTourEnLigneLePortablePrend() {
        let membres = [membre(portable), membre(tour, enLigne: false, sansEcran: true)]
        #expect(SelectionNoeud.choisir(membres, moi: moi, appaires: [portable, tour], prefere: nil) == portable)
    }

    @Test func unNoeudNonAppaireNestPasChoisiSiDautresSontAppaires() {
        let membres = [membre("dddddddddddd", sansEcran: true), membre(portable)]
        #expect(SelectionNoeud.choisir(membres, moi: moi, appaires: [portable], prefere: nil) == portable)
    }

    @Test func premierAppairageEvitelesNoeudsSansEcran() {
        let membres = [membre(tour, sansEcran: true), membre(portable)]
        #expect(SelectionNoeud.choisir(membres, moi: moi, appaires: [], prefere: nil) == portable)
        #expect(SelectionNoeud.choisir([membre(tour, sansEcran: true)], moi: moi, appaires: [], prefere: nil) == nil)
    }

    @Test func refusesSontExclus() {
        let membres = [membre(portable), membre(tour, sansEcran: true)]
        #expect(SelectionNoeud.choisir(membres, moi: moi, appaires: [portable, tour], prefere: nil, refuses: [tour]) == portable)
    }

    @Test func aucunNoeudEnLigneDonneNil() {
        let membres = [membre(portable, enLigne: false), membre(moi, genre: "appareil")]
        #expect(SelectionNoeud.choisir(membres, moi: moi, appaires: [portable], prefere: nil) == nil)
    }

    @Test func genreAbsentNestPasUnNoeud() {
        #expect(SelectionNoeud.choisir([membre(portable, genre: nil)], moi: moi, appaires: [], prefere: nil) == nil)
    }
}
