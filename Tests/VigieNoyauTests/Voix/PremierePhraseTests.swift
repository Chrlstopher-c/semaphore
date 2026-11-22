import Testing
@testable import VigieNoyau

private func dire(_ deltas: [String], bloc: String = "b1") -> [String] {
    var d = DecoupePhrases()
    var sorties: [String] = []
    for delta in deltas { sorties += d.ajouter(delta, bloc: bloc) }
    return sorties
}

@Test func unePremierePhraseLongueSeCoupeAvantSaFin() {
    let sorties = dire([
        "Je regarde les résultats de tous les tests du dépôt, puis je te dis ce qui échoue vraiment ici. Ensuite",
    ])
    #expect(sorties == [
        "Je regarde les résultats de tous les tests du dépôt,",
        "puis je te dis ce qui échoue vraiment ici.",
    ])
}

@Test func unePremierePhraseCourteAttendLaFinDeLaPhrase() {
    let sorties = dire(["Il y a 3.5 litres de café dans la machine du bureau. Ensuite"])
    #expect(sorties == ["Il y a 3.5 litres de café dans la machine du bureau."])
}

@Test func lesNombresDecimauxNeCoupentPasUneSuitePhrase() {
    let sorties = dire([
        "Le build est vert avec 3.5 secondes de marge sur la branche principale, tout passe sans aucune erreur. Le reste attend",
    ])
    #expect(sorties == [
        "Le build est vert avec 3.5 secondes de marge sur la branche principale,",
        "tout passe sans aucune erreur.",
    ])
}
