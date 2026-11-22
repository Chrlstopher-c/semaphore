import Testing
@testable import VigieNoyau

private func dire(_ deltas: [String], bloc: String = "b1") -> (DecoupePhrases, [String]) {
    var d = DecoupePhrases()
    var sorties: [String] = []
    for delta in deltas { sorties += d.ajouter(delta, bloc: bloc) }
    return (d, sorties)
}

@Test func lePremierMorceauPartALaPremiereVirgule() {
    let (_, sorties) = dire(["D'accord, je regarde", " les journaux, puis je ", "te dis."])
    #expect(sorties == ["D'accord, je regarde les journaux,"])
}

@Test func lesPhrasesSuivantesPartentEntieres() {
    let (d0, s0) = dire(["Bonjour, voilà ce que je vois. Le build ", "est vert, tout passe. Il reste", " un test."])
    var d = d0
    #expect(s0 == ["Bonjour, voilà ce que je vois.", "Le build est vert, tout passe."])
    #expect(d.finir(texteFinal: nil) == ["Il reste un test."])
}

@Test func leTexteFinalComplèteCeQuiAManqueEnDirect() {
    var (d, _) = dire(["Je regarde ça tout de suite. Et"])
    #expect(d.finir(texteFinal: "Je regarde ça tout de suite. Et voilà le résultat.") == ["Et voilà le résultat."])
}

@Test func unTexteFinalSansDirectEstDitEntier() {
    var d = DecoupePhrases()
    #expect(d.finir(texteFinal: "Fait.") == ["Fait."])
}

@Test func unNouveauBlocTermineLePrecedent() {
    var d = DecoupePhrases()
    _ = d.ajouter("Je lance les tests maintenant", bloc: "b1")
    #expect(d.ajouter("Tout", bloc: "b2") == ["Je lance les tests maintenant"])
}

@Test func leMarkdownEstRetire() {
    #expect(DecoupePhrases.nettoyer("## Titre\n- **gras** et `code` [lien](http://x)") == "Titre gras et code lien")
}

@Test func lesAbreviationsNeCoupentPas() {
    let (_, sorties) = dire(["J'ai vu M. Dupont hier soir au bureau. Ensuite"])
    #expect(sorties == ["J'ai vu M. Dupont hier soir au bureau."])
}

@Test func lAnnonceEntreeVaDevantLePremierMessage() {
    #expect(ReglesVocales.message("Salut", premier: true).hasPrefix("[Mode vocal activé"))
    #expect(ReglesVocales.message("Salut", premier: false) == "Salut")
    #expect(ReglesVocales.apresSortie("Ok").hasPrefix("[Mode vocal terminé]"))
}

@Test func onCoupeSurDeVraisMotsPasSurLEcho() {
    #expect(ReglesVocales.couperLecture(entendu: "attends stop", phraseLue: "Le build est vert."))
    #expect(!ReglesVocales.couperLecture(entendu: "euh", phraseLue: nil))
    #expect(!ReglesVocales.couperLecture(entendu: "le build est", phraseLue: "Le build est vert."))
    #expect(!ReglesVocales.couperLecture(entendu: "hum ok", phraseLue: nil))
    #expect(ReglesVocales.couperLecture(entendu: "attends", phraseLue: "Le build est vert."))
    let rappel = ReglesVocales.apresCoupure("redis-moi", dit: "Le build est vert.")
    #expect(rappel.contains("« Le build est vert. »") && rappel.hasSuffix("redis-moi"))
}
