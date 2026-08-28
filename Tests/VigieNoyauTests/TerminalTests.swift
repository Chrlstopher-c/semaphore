import Foundation
import Testing

@testable import VigieNoyau

@Suite("Terminal — épuration ANSI, touches d'accessoires et tri des sessions")
struct TerminalTests {

    // MARK: - EpurationAnsi

    @Test("retire les séquences CSI de couleur et de curseur")
    func sequencesCSI() {
        let brut = "\u{1B}[32mOK\u{1B}[0m \u{1B}[?25l\u{1B}[Ktexte"
        #expect(EpurationAnsi.epurer(brut) == "OK texte")
    }

    @Test("consomme les séquences OSC jusqu'à leur terminateur BEL")
    func sequenceOSC() {
        let brut = "\u{1B}]0;titre de fenêtre\u{07}reste"
        #expect(EpurationAnsi.epurer(brut) == "reste")
    }

    @Test("un retour chariot réécrit la ligne : seul le dernier segment survit")
    func retourChariot() {
        #expect(EpurationAnsi.epurer("ancien\rnouveau") == "nouveau")
    }

    @Test("rogne les lignes vides de fin, jamais celles du milieu")
    func rognageFin() {
        let brut = "ligne 1\n\nligne 2\n\n\n"
        #expect(EpurationAnsi.epurer(brut) == "ligne 1\n\nligne 2")
    }

    // MARK: - ToucheTerminal

    @Test("chaque touche de la barre se retrouve par son code")
    func rechercheParCode() {
        for touche in ToucheTerminal.toutes {
            #expect(ToucheTerminal.pour(code: touche.code) == touche)
        }
        #expect(ToucheTerminal.pour(code: "inconnu") == nil)
    }

    @Test("ctrl est le seul modificateur, sans séquence propre")
    func modificateur() {
        #expect(ToucheTerminal.controle.estModificateur)
        #expect(ToucheTerminal.toutes.filter(\.estModificateur) == [.controle])
    }

    @Test("Ctrl-C et Ctrl-D produisent les octets de contrôle attendus")
    func sequencesControle() {
        #expect(ToucheTerminal.sequenceControle("c") == "\u{03}")
        #expect(ToucheTerminal.sequenceControle("C") == "\u{03}")
        #expect(ToucheTerminal.sequenceControle("d") == "\u{04}")
    }

    @Test("hors de A-Z, aucune séquence de contrôle ne se compose")
    func sequenceControleHorsAlphabet() {
        #expect(ToucheTerminal.sequenceControle("7") == nil)
        #expect(ToucheTerminal.sequenceControle("é") == nil)
    }

    // MARK: - TriSessions

    private func session(_ nom: String, attachee: Bool, cree: Int) throws -> SessionTmuxApi {
        let corps = Data(#"{"name": "\#(nom)", "created": \#(cree), "attached": \#(attachee)}"#.utf8)
        return try JSONDecoder().decode(SessionTmuxApi.self, from: corps)
    }

    @Test("les sessions attachées passent devant, puis les plus récentes")
    func tri() throws {
        let ancienneAttachee = try session("a", attachee: true, cree: 100)
        let recenteDetachee = try session("b", attachee: false, cree: 300)
        let recenteAttachee = try session("c", attachee: true, cree: 200)
        let trie = TriSessions.triees([recenteDetachee, ancienneAttachee, recenteAttachee])
        #expect(trie.map(\.name) == ["c", "a", "b"])
    }
}
