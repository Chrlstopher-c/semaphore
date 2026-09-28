// La lampe : l'état du ruban tel que le Pi le rapporte, et la file des gestes à lui envoyer.
#if canImport(UIKit)
import LueurNoyau
import Observation

enum Joignabilite: Equatable {
    case inconnue, jointe, injoignable, sansAdresse
}

@MainActor @Observable
final class Lampe {
    private(set) var etat: EtatLumiere?
    private(set) var effets: [Effet] = []
    private(set) var joignabilite: Joignabilite = .inconnue
    /// La couleur sous le doigt pendant un glissé : l'écran la suit sans attendre l'aller-retour du Pi.
    private(set) var apercu: Nuance?
    /// Incrémenté quand une trame n'a pas atteint le ruban — déclencheur de l'haptique d'échec.
    private(set) var echecs = 0

    @ObservationIgnored private let client = Client()
    @ObservationIgnored private var file = FileCommandes()
    @ObservationIgnored private var enVol = false
    @ObservationIgnored private var releve: Task<Void, Never>?

    /// Unique par processus, comme l'émetteur d'Iris : un `@State Lampe()` serait recréé par SwiftUI.
    static let partage = Lampe()

    private init() {}

    var couleur: Nuance? { apercu ?? etat.flatMap { Nuance(hexa: $0.couleur) } }

    /// Relevé toutes les 8 s tant que le monde est devant ; rien au lancement quand il est caché.
    func montrer(_ visible: Bool) {
        releve?.cancel()
        guard visible else { return }
        releve = Task { [weak self] in
            if self?.effets.isEmpty == true { await self?.chargerEffets() }
            while !Task.isCancelled {
                await self?.relever()
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }

    func envoyer(_ commande: Commande) {
        if case .couleur(let nuance) = commande { apercu = nuance }
        file.deposer(commande)
        guard !enVol else { return }
        enVol = true
        Task { await vider() }
    }

    private func vider() async {
        while let commande = file.prendre() {
            do {
                let reponse = try await client.envoyer(commande)
                if !reponse.envoye { echecs += 1 }
                if file.estVide { etat = reponse.etat }
                joignabilite = .jointe
            } catch {
                noterPanne(error)
            }
        }
        apercu = nil
        enVol = false
    }

    private func relever() async {
        guard !enVol else { return }
        do {
            let nouvel = try await client.etat()
            if !enVol { etat = nouvel }
            joignabilite = .jointe
        } catch {
            noterPanne(error)
        }
    }

    private func chargerEffets() async {
        effets = (try? await client.effets()) ?? []
    }

    private func noterPanne(_ erreur: Error) {
        if case PanneLiaison.sansAdresse = erreur {
            joignabilite = .sansAdresse
        } else {
            if joignabilite == .jointe { echecs += 1 }
            joignabilite = .injoignable
        }
    }
}
#endif
