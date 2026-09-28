// L'état du parc vu par Vigie, tenu à jour par un long-poll (`/api/attente`) tant que l'app est au premier plan :
// une requête en vol à la fois, rendue par le relais dès qu'une session, un fil ou une notification change.
#if canImport(SwiftUI)
import Foundation
import Observation
import VigieNoyau

@MainActor @Observable
public final class ModeleRelais {
    public enum Lien: Equatable { case attente, connecte, coupe(String), nonConnecte }

    public private(set) var lien: Lien = .attente
    public private(set) var sessions: [Session] = []
    public private(set) var machines: [Machine] = []
    public private(set) var notifications: [NotificationRelais] = []
    public private(set) var reveilPossible: [String] = []
    public private(set) var fils: [String: [EvenementDate]] = [:]
    @ObservationIgnored private(set) var client: ClientRelais?
    @ObservationIgnored private var boucle: Task<Void, Never>?
    @ObservationIgnored private var version = -1

    public init() {}

    func brancher(_ client: ClientRelais?) {
        arreter()
        self.client = client
        lien = client == nil ? .nonConnecte : .attente
        if client == nil { sessions = []; machines = []; notifications = []; fils = [:] }
    }

    func demarrer() {
        guard client != nil, boucle == nil else { return }
        boucle = Task { [weak self] in await self?.veiller() }
    }

    func arreter() {
        boucle?.cancel()
        boucle = nil
    }

    private func veiller() async {
        var attenteErreur: UInt64 = 2
        while !Task.isCancelled, let client {
            do {
                if version < 0 { try await charger(client) } else { try await attendre(client) }
                attenteErreur = 2
            } catch ErreurRelais.nonConnecte {
                lien = .nonConnecte
                return
            } catch {
                if Task.isCancelled { return }
                lien = .coupe("\(error)")
                version = -1
                try? await Task.sleep(nanoseconds: attenteErreur * 1_000_000_000)
                attenteErreur = min(attenteErreur * 2, 30)
            }
        }
    }

    private func charger(_ client: ClientRelais) async throws {
        let e: EtatRelais = try await client.lire(Route.etat)
        appliquer(version: e.version, sessions: e.sessions, machines: e.machines)
        notifications = e.notifications
        reveilPossible = e.reveilPossible
        await CentreAlerte.partage.sonner(e.notifications)
        lien = .connecte
    }

    private func attendre(_ client: ClientRelais) async throws {
        let dernier = notifications.first?.seq ?? 0
        let r: ReponseAttente = try await client.lire(Route.attente(version: version, notifications: dernier))
        appliquer(version: r.version, sessions: r.sessions, machines: r.machines)
        if !r.notifications.isEmpty {
            notifications = (r.notifications + notifications.filter { $0.seq <= dernier }).prefix(200).map { $0 }
            await CentreAlerte.partage.sonner(r.notifications)
        }
        lien = .connecte
    }

    private func appliquer(version: Int, sessions: [Session], machines: [Machine]) {
        self.version = version
        self.sessions = sessions.sorted { $0.majLe > $1.majLe }
        self.machines = machines
    }

    // MARK: - Fil d'une session

    /// Charge le fil puis le prolonge en direct tant que la tâche appelante vit (écran de la session visible).
    func suivreFil(_ id: String) async {
        guard let client else { return }
        do {
            let debut: [EvenementDate] = try await client.lire(Route.evenements(id))
            fils[id] = debut
        } catch {
            Trace.erreur("relais", "fil \(id) non chargé", error)
        }
        while !Task.isCancelled {
            let apres = fils[id]?.last?.seq ?? 0
            do {
                let suite: [EvenementDate] = try await client.lire(Route.evenements(id, apres: apres, attendre: 25))
                if !suite.isEmpty { fils[id, default: []].append(contentsOf: suite.filter { $0.seq > apres }) }
            } catch {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    public func session(_ id: String) -> Session? {
        sessions.first { $0.id == id }
    }
}
#endif
