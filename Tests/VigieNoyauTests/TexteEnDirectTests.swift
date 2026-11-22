import Testing
@testable import VigieNoyau

@Test func lesDeltasDuMemeBlocSeCumulentEtUnBlocNeufRepartDeZero() {
    var c = CumulDirect(bloc: "m1:0")
    c.ajouter("Bon", bloc: "m1:0")
    c.ajouter("jour", bloc: "m1:0")
    #expect(c.texte == "Bonjour")
    c.ajouter("Ensuite", bloc: "m2:0")
    #expect(c.texte == "Ensuite")
    #expect(c.bloc == "m2:0")
}

@Test func leRythmeMontreDesMotsEntiersEtNeDepassePasLeTexte() {
    let texte = Array("Voici une réponse")
    let premier = RythmeDirect.suivant(affiches: 0, dans: texte)
    #expect(String(texte.prefix(premier)) == "Voici")
    var n = 0
    for _ in 0..<100 { n = RythmeDirect.suivant(affiches: n, dans: texte) }
    #expect(n == texte.count)
}

@Test func unGrosRetardSeResorbeEnUneSecondeEnviron() {
    let texte = Array(String(repeating: "mot ", count: 300))
    var n = 0
    for _ in 0..<(RythmeDirect.cadence / 2) { n = RythmeDirect.suivant(affiches: n, dans: texte) }
    #expect(n > texte.count * 3 / 4)
    for _ in 0..<RythmeDirect.cadence { n = RythmeDirect.suivant(affiches: n, dans: texte) }
    #expect(n == texte.count)
}

@Test func auFilDeLEauLeTexteSAfficheParPetitsPas() {
    // 2 caractères par pas au minimum : un texte qui arrive lentement s'écrit sans à-coup ni attente.
    let texte = Array("abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz")
    let n = RythmeDirect.suivant(affiches: texte.count - 2, dans: texte)
    #expect(n == texte.count)
    let m = RythmeDirect.suivant(affiches: 0, dans: Array("a b"))
    #expect(m == 1 || m == 3)
}

@Test func unTexteRemplaceRepartDeZeroUnTexteProlongeGardeSonAvance() {
    let ancien = Array("Bonjour à toi")
    #expect(RythmeDirect.conserve(affiches: 7, ancien: ancien, nouveau: Array("Bonjour à toi, Chris")) == 7)
    #expect(RythmeDirect.conserve(affiches: 7, ancien: ancien, nouveau: Array("Autre chose")) == 0)
    #expect(RythmeDirect.conserve(affiches: 7, ancien: ancien, nouveau: Array("Bon")) == 3)
}
