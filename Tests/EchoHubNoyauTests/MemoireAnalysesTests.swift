import Testing
@testable import EchoHubNoyau

@Suite("Mémoire des analyses")
struct MemoireAnalysesTests {
    @Test func calculeUneSeuleFoisEtSeVideQuandPleine() {
        let memoire = MemoireAnalyses<Int>(capacite: 2)
        var calculs = 0
        for _ in 0..<3 { _ = memoire.valeur("a") { calculs += 1; return 1 } }
        #expect(calculs == 1)
        _ = memoire.valeur("b") { 2 }
        _ = memoire.valeur("c") { 3 }
        _ = memoire.valeur("a") { calculs += 1; return 1 }
        #expect(calculs == 2)
    }

    @Test func memeResultatQueLAnalyseDirecte() {
        let texte = "# Titre\n\nUn **gras** et du `code`."
        #expect(AnalyseMarkdown.analyserMemorise(texte) == AnalyseMarkdown.analyser(texte))
    }

    @Test func uneCleSuitLeTexteQuiSAllonge() {
        let debut = "<think>a</think>Bonjour"
        let suite = debut + " Chris"
        #expect(SegmenteurReponse.segmenterMemorise(debut, cle: "m1") == SegmenteurReponse.segmenter(debut))
        #expect(SegmenteurReponse.segmenterMemorise(suite, cle: "m1") == SegmenteurReponse.segmenter(suite))
    }
}
