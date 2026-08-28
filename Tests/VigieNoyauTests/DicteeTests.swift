import Foundation
import Testing

@testable import VigieNoyau

@Suite("Dictée — assemblage des segments par-dessus le brouillon")
struct DicteeTests {

    @Test("une dictée neuve rend la phrase en cours telle quelle")
    func phraseEnCours() {
        var assemblage = AssemblageDictee()
        assemblage.poser("relance la compilation")
        #expect(assemblage.texte == "relance la compilation")
    }

    @Test("une phrase close survit à celle qui la suit")
    func pauseNEffacePas() {
        var assemblage = AssemblageDictee()
        assemblage.poser("relance la compilation")
        assemblage.consolider()
        assemblage.poser("puis relis les journaux")
        #expect(assemblage.texte == "relance la compilation puis relis les journaux")
    }

    @Test("la dictée s'ajoute au brouillon déjà tapé, séparée d'un espace")
    func suiteDuBrouillon() {
        var assemblage = AssemblageDictee(base: "note :")
        assemblage.poser("le socket gèle en deux secondes")
        #expect(assemblage.texte == "note : le socket gèle en deux secondes")
    }

    @Test("aucun espace ajouté après un saut de ligne ou un espace déjà là")
    func jointureRespectee() {
        var avecRetour = AssemblageDictee(base: "titre\n")
        avecRetour.poser("corps")
        #expect(avecRetour.texte == "titre\ncorps")

        var avecEspace = AssemblageDictee(base: "titre ")
        avecEspace.poser("corps")
        #expect(avecEspace.texte == "titre corps")
    }

    @Test("tant que rien n'est reconnu, le brouillon est rendu intact")
    func brouillonIntact() {
        var assemblage = AssemblageDictee(base: "déjà tapé")
        #expect(assemblage.vide)
        #expect(assemblage.texte == "déjà tapé")
        assemblage.poser("   ")
        #expect(assemblage.vide)
        #expect(assemblage.texte == "déjà tapé")
    }

    @Test("un segment vide n'entre jamais dans l'acquis")
    func silenceIgnore() {
        var assemblage = AssemblageDictee()
        assemblage.poser("  ")
        assemblage.consolider()
        assemblage.poser("un mot")
        #expect(assemblage.texte == "un mot")
    }

    @Test("les espaces de bord d'un segment sont rognés à la consolidation")
    func rognage() {
        var assemblage = AssemblageDictee()
        assemblage.poser("  première phrase  ")
        assemblage.consolider()
        assemblage.poser("  seconde  ")
        #expect(assemblage.texte == "première phrase seconde")
    }

    @Test("une correction au clavier devient la nouvelle base")
    func correctionAuClavier() {
        var assemblage = AssemblageDictee()
        assemblage.poser("relance la compilation")
        assemblage.consolider()
        assemblage.reprendreSur("relance le build")
        assemblage.poser("maintenant")
        #expect(assemblage.texte == "relance le build maintenant")
    }
}
