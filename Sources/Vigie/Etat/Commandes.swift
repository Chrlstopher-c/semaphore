// Ce que Chris fait depuis Vigie — parler à une session, la piloter, en ouvrir une, agir sur le parc.
// Chaque commande rend l'erreur à afficher, ou nil.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

extension ModeleRelais {
    private struct Texte: Encodable { let texte: String }
    private struct Active: Encodable { let active: Bool }
    private struct Jusqua: Encodable { let jusqua: Int }

    func envoyer(_ texte: String, a session: String) async -> String? {
        await executer { try await $0.ecrire(Route.messages(session), Texte(texte: texte)) }
    }

    func agir(_ action: ActionSession, sur session: String) async -> String? {
        await executer { try await $0.ecrire(Route.action(session, action), Vide()) }
    }

    func repondre(_ reponse: ReponseDialogue, a session: String) async -> String? {
        await executer { try await $0.ecrire(Route.repondre(session), reponse) }
    }

    func basculerAutonomie(_ active: Bool, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.autonomie(session), Active(active: active)) }
    }

    func ouvrir(_ demande: DemandeOuverture) async -> Result<Session, ErreurRelais> {
        guard let client else { return .failure(.nonConnecte) }
        do {
            return .success(try await client.ouvrir(demande))
        } catch let erreur as ErreurRelais {
            return .failure(erreur)
        } catch {
            return .failure(.injoignable("\(error)"))
        }
    }

    func marquerLues() async -> String? {
        guard let derniere = notifications.first?.seq else { return nil }
        return await executer { try await $0.ecrire(Route.notificationsLues, Jusqua(jusqua: derniere)) }
    }

    func reveiller(_ machine: String) async -> String? {
        await executer { try await $0.ecrire(Route.reveiller(machine), Vide()) }
    }

    func eteindre(_ machine: String) async -> String? {
        await executer { try await $0.ecrire(Route.eteindre(machine), Vide()) }
    }

    private func executer(_ f: (ClientRelais) async throws -> Vide) async -> String? {
        guard let client else { return ErreurRelais.nonConnecte.description }
        do {
            _ = try await f(client)
            return nil
        } catch {
            Trace.erreur("relais", "commande refusée", error)
            return "\(error)"
        }
    }
}
#endif
