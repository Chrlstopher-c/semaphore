import Foundation
import Testing
@testable import EchoHubNoyau

@Suite("État de la tour")
struct TourTests {
    let maintenant = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func decodeLaReponseDuRelais() throws {
        let json = """
        {"tour":"allumee","echohub":"pret","modele":{"etat":"pret","nom":"org/depot::CyberTiel-IQ4_XS.gguf"},
         "demarrage":"aucun","reveil_envoye_le":null,"mesure_le":"2026-11-27T22:49:18.074Z"}
        """
        let etat = try CodageJSON.decodeur().decode(EtatTour.self, from: Data(json.utf8))
        #expect(etat.modele?.nom == "org/depot::CyberTiel-IQ4_XS.gguf")
        #expect(PhaseTour.depuis(etat) == .prete(modele: "CyberTiel-IQ4_XS"))
    }

    @Test func eteinteSansReveil() {
        #expect(PhaseTour.depuis(EtatTour(tour: "eteinte", echohub: "injoignable")) == .eteinte)
    }

    @Test func allumageApresReveilRecentPuisEteinteApresDelai() {
        let recent = EtatTour(tour: "eteinte", echohub: "injoignable",
                              reveilEnvoyeLe: maintenant.addingTimeInterval(-30))
        #expect(PhaseTour.depuis(recent, maintenant: maintenant) == .allumage)
        let vieux = EtatTour(tour: "eteinte", echohub: "injoignable",
                             reveilEnvoyeLe: maintenant.addingTimeInterval(-600))
        #expect(PhaseTour.depuis(vieux, maintenant: maintenant) == .eteinte)
    }

    @Test func tourAllumeeSelonLeDemarrage() {
        #expect(PhaseTour.depuis(EtatTour(tour: "allumee", echohub: "injoignable")) == .echohubArrete)
        #expect(PhaseTour.depuis(EtatTour(tour: "allumee", echohub: "injoignable", demarrage: "en_cours")) == .demarrage)
        #expect(PhaseTour.depuis(EtatTour(tour: "allumee", echohub: "injoignable", demarrage: "echoue")) == .demarrageEchoue)
    }

    @Test func pretSansModeleCharge() {
        let etat = EtatTour(tour: "allumee", echohub: "pret", modele: ModeleTour(etat: "inactif", nom: nil))
        #expect(PhaseTour.depuis(etat) == .prete(modele: nil))
    }
}

@Suite("Migration de l'adresse du relais")
struct MigrationRelaisTests {
    @Test func httpCedeAuTunnelEtGardeLeJeton() {
        let migre = ReglagesRelais(adresse: "http://192.0.2.9:8947", jeton: "j").migre(versDefaut: "https://relais.example")
        #expect(migre == ReglagesRelais(adresse: "https://relais.example", jeton: "j"))
    }

    @Test func rienNeBougeSansTunnelOuDejaEnHttps() {
        let local = ReglagesRelais(adresse: "http://192.0.2.9:8947", jeton: "j")
        #expect(local.migre(versDefaut: "http://192.0.2.1:8947") == local)
        let tunnel = ReglagesRelais(adresse: "https://autre.example", jeton: "j")
        #expect(tunnel.migre(versDefaut: "https://relais.example") == tunnel)
    }
}
