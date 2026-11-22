import Testing
@testable import VigieNoyau

@Test func lesPartielsRemplacentSeulementLeSegmentEnCours() {
    var c = CumulDictee(base: "Salut")
    c.resultat("je", fin: false)
    c.resultat("je voudrais", fin: false)
    c.resultat("je voudrais un café", fin: false)
    #expect(c.texte == "Salut je voudrais un café")
}

@Test func unResultatFinalEstCumuleEtUnNouveauSegmentCommence() {
    var c = CumulDictee(base: "")
    c.resultat("Première phrase.", fin: true)
    c.resultat("Deuxième", fin: false)
    #expect(c.texte == "Première phrase. Deuxième")
    c.resultat("Deuxième phrase.", fin: true)
    #expect(c.texte == "Première phrase. Deuxième phrase.")
}

@Test func unPartielQuiRepartSansFinalFigeLePrecedent() {
    var c = CumulDictee(base: "")
    c.resultat("Bonjour Claude", fin: false)
    c.resultat("Regarde", fin: false) // silence : Speech recommence sans résultat final
    c.resultat("Regarde les logs", fin: false)
    #expect(c.texte == "Bonjour Claude Regarde les logs")
}

@Test func uneRevisionDuMemeSegmentNEstPasUnRedemarrage() {
    var c = CumulDictee(base: "")
    c.resultat("bonjour cloud", fin: false)
    c.resultat("Bonjour Claude,", fin: false)
    #expect(c.texte == "Bonjour Claude,")
}

@Test func laTacheQuiRedemarreGardeLePartiel() {
    var c = CumulDictee(base: "a")
    c.resultat("une minute de parole", fin: false)
    c.figer()
    c.resultat("et la suite", fin: false)
    #expect(c.texte == "a une minute de parole et la suite")
}

@Test func uneRetoucheALaMainDevientLaBase() {
    var c = CumulDictee(base: "")
    c.resultat("texte dicté", fin: true)
    c.champModifie("texte corrigé")
    c.resultat("puis encore", fin: false)
    #expect(c.texte == "texte corrigé puis encore")
}

@Test func pasDEspaceAvantUnePonctuation() {
    #expect(CumulDictee.joindre("Bonjour", ", ça va") == "Bonjour, ça va")
    #expect(CumulDictee.joindre("Bonjour ", "toi") == "Bonjour toi")
}
