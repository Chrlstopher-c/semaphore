// Le programme du ruban : les routines et leurs instructions, lues sur le Pi et modifiées depuis l'app. Les écritures
// partent tout de suite à l'écran (comme les gestes de la lampe), puis on relit le Pi pour le prochain passage.
#if canImport(UIKit)
import LueurNoyau
import Observation

@MainActor @Observable
final class Programme {
    private(set) var routines: [Routine] = []
    private(set) var scenarios: [String: Scenario] = [:]
    private(set) var charge = false
    private(set) var panne: String?
    @ObservationIgnored private let client = Client()
    /// Le scénario d'essai de l'éditeur (instructions non enregistrées), accéléré à ~15 s, pleine lumière (Chris, 28/11).
    static let essai = "apercu-iphone"
    static let partage = Programme()
    private init() {}

    var triees: [Routine] { routines.sorted { $0.heure < $1.heure } }

    func etapes(de routine: Routine) -> [Etape] { scenarios[routine.scenario]?.etapes ?? [] }
    func duree(de routine: Routine) -> Double { scenarios[routine.scenario]?.duree ?? 0 }

    func charger() async {
        do {
            let liste = try await client.scenarios()
            scenarios = Dictionary(liste.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            routines = try await client.routines()
            charge = true
            panne = nil
        } catch {
            panne = Programme.message(error)
        }
    }

    /// Enregistre les instructions puis la routine. Rend le message d'erreur, ou nil.
    func enregistrer(_ routine: Routine, etapes: [Etape]) async -> String? {
        let nom = scenarios[routine.scenario]?.nom ?? routine.nom
        let scenario = Scenario(id: routine.scenario, nom: nom, etapes: etapes.map(\.propre))
        do {
            try await client.ecrire(scenario)
            try await client.ecrire(routine)
            scenarios[scenario.id] = scenario
            routines.removeAll { $0.id == routine.id }
            routines.append(routine)
            await charger()
            return nil
        } catch {
            return Programme.message(error)
        }
    }

    func basculer(_ routine: Routine, active: Bool) {
        var r = routine
        r.active = active
        if let i = routines.firstIndex(where: { $0.id == r.id }) { routines[i] = r }
        Task {
            do { try await client.ecrire(r) } catch { panne = Programme.message(error) }
            await charger()
        }
    }

    /// La routine, puis ses instructions si plus aucune autre routine ne s'en sert.
    func supprimer(_ routine: Routine) async -> String? {
        do {
            try await client.supprimerRoutine(routine.id)
            routines.removeAll { $0.id == routine.id }
            if !routines.contains(where: { $0.scenario == routine.scenario }) {
                try? await client.supprimerScenario(routine.scenario)
                scenarios[routine.scenario] = nil
            }
            return nil
        } catch {
            return Programme.message(error)
        }
    }

    func essayer(_ etapes: [Etape]) async -> String? {
        do {
            let apercu = Horaire.acceleree(etapes.map(\.propre))
            try await client.ecrire(Scenario(id: Programme.essai, nom: "Essai", etapes: apercu))
            try await client.jouer(Programme.essai, plafond: 100)
            return nil
        } catch {
            return Programme.message(error)
        }
    }

    func arreter() async { try? await client.arreter() }

    func oublierEssai() async { try? await client.supprimerScenario(Programme.essai) }

    private static func message(_ erreur: Error) -> String {
        switch erreur {
        case PanneLiaison.sansAdresse: return "Adresse du Pi absente"
        case PanneLiaison.refus(let texte): return "Refusé par le Pi : \(texte)"
        case PanneLiaison.reponse(let code): return "Le Pi a répondu \(code)"
        default: return "Pi injoignable"
        }
    }
}
#endif
