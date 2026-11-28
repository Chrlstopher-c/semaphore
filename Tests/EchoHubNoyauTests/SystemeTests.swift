import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("Système")
struct SystemeTests {
    @Test func moteursEtServicesReels() throws {
        let moteurs = """
        {"llamacpp":{"moteur":"llamacpp","statut":"fonctionnel","version":"0.3.36","architectures_gpu":["sm_86"],"diagnostic":"ok","remediation":"","details":{},"installe":true,"fonctionnel":true,"couvre_le_parc":true},
         "vllm":{"moteur":"vllm","statut":"absent","version":null,"architectures_gpu":null,"diagnostic":"non installé","remediation":"Installer une version.","details":{},"installe":false,"fonctionnel":false},
         "versions_vllm":[],"mesure_le":"x"}
        """
        let etat = try CodageJSON.decodeur().decode(EtatMoteurs.self, from: Data(moteurs.utf8))
        #expect(etat.llamacpp.fonctionnel && !etat.vllm.installe)
        let services = #"[{"nom":"Moteur","role":"Génère les réponses","etat":"ok","detail":"modèle"}]"#
        #expect(try CodageJSON.decodeur().decode([ServicePile].self, from: Data(services.utf8)).first?.etat == "ok")
    }

    @Test func tramesDInstallation() {
        let pas = TrameSSE(evenement: nil, donnees: #"{"version":"0.31.0","etape":"pip","message":"Installation de torch","niveau":"info","progression":0.4,"termine":false,"succes":null,"horodatage":"t"}"#)
        guard case .pas(let evenement)? = DepotSysteme.lire(pas) else { Issue.record("pas non lu"); return }
        #expect(evenement.progression == 0.4)
        let erreur = TrameSSE(evenement: nil, donnees: #"{"code":"X","message":"Disque plein.","remediation":"Libérer 10 Go."}"#)
        #expect(DepotSysteme.lire(erreur) == .echec("Disque plein. Libérer 10 Go."))
    }
}
