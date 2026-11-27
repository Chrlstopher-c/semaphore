import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Ligne d'activité de l'agent")
struct ActiviteTests {
    private func activite(_ phase: String, tokens: Int = 10) -> ActiviteMoteur {
        let json = #"{"phase":"\#(phase)","tokens":\#(tokens),"tokens_par_seconde":20}"#
        return try! CodageJSON.decodeur().decode(ActiviteMoteur.self, from: Data(json.utf8))
    }

    @Test func phasesCommeLeWeb() {
        #expect(RepereActivite(activite("texte"), silencieux: false).libelle == "Rédaction")
        #expect(RepereActivite(activite("execution"), silencieux: false).ton == .alerte)
        #expect(!RepereActivite(activite("lecture"), silencieux: false).montrerJetons)
        #expect(!RepereActivite(activite("texte", tokens: 0), silencieux: false).montrerJetons)
    }

    @Test func leSilenceSeVoitSaufPendantUneExecution() {
        #expect(RepereActivite(activite("texte"), silencieux: true).libelle == "Aucune nouvelle du moteur")
        #expect(RepereActivite(activite("execution"), silencieux: true).libelle == "Exécute")
    }

    @Test func dureesEtTaches() {
        #expect(RepereActivite.duree(12) == "12 s")
        #expect(RepereActivite.duree(185) == "3 min 05 s")
        #expect(RepereActivite.duree(3720) == "1 h 02 min")
        #expect(["todo", "in_progress", "fait", "blocked", "abandonne"].map { EtatTache($0).marque } == ["○", "◐", "✓", "!", "–"])
    }
}
