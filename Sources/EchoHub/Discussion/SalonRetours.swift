// Les retours sur les réponses (`useVerdict.ts` du web) : pouce, raisons, correction, écrits sur le PC.
#if canImport(SwiftUI)
import Foundation
import EchoHubNoyau

extension Salon {
    var depotRetours: DepotRetours { DepotRetours(client: client) }

    func chargerRetours() async {
        guard let id = conversation?.id else { return }
        do {
            retours = try await depotRetours.resume(id)
        } catch {
            Journal.echec("retours illisibles : \(error)")
        }
    }

    /// Pose un verdict ; retoucher le même le retire. `nil` en retour = réussi, sinon le message d'erreur.
    func noter(
        _ message: MessageChat, _ verdict: Verdict, raisons: [RaisonRetour]? = nil, correction: String? = nil
    ) async -> String? {
        guard let id = conversation?.id, !Self.estLocal(message.id) else { return nil }
        let retire = Retours.retire(actuel: retours.parMessage[message.id], nouveau: verdict, raisons: raisons)
        do {
            if retire {
                try await depotRetours.retirer(message.id)
            } else {
                try await depotRetours.noter(DemandeRetour(
                    conversationId: id, messageId: message.id, verdict: verdict,
                    correction: correction, raisons: raisons ?? []
                ))
            }
            retours.parMessage[message.id] = retire ? nil : verdict
            retours.raisonsParMessage[message.id] = retire ? nil : (raisons ?? [])
            return nil
        } catch {
            Journal.echec("retour non enregistré : \(error)")
            return Self.libelle(error)
        }
    }
}
#endif
