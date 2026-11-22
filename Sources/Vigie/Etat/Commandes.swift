// Ce que Chris fait depuis Vigie — parler à une session, la piloter, en ouvrir une, agir sur le parc.
// Chaque commande rend l'erreur à afficher, ou nil. L'état qui en découle revient par le flux, sans rechargement.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

extension ModeleRelais {
    private struct Jusqua: Encodable { let jusqua: Int }

    public func envoyer(_ texte: String, a session: String) async -> String? {
        await executer { try await $0.ecrire(Route.messages(session), CorpsTexte(texte: texte)) }
    }

    public func agir(_ action: ActionSession, sur session: String) async -> String? {
        await executer { try await $0.ecrire(Route.action(session, action), Vide()) }
    }

    public func interrompre(_ session: String) async -> String? {
        await agir(.interrompre, sur: session)
    }

    public func repondre(_ reponse: ReponseDialogue, a session: String) async -> String? {
        await executer { try await $0.ecrire(Route.repondre(session), reponse) }
    }

    public func basculerAutonomie(_ active: Bool, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.autonomie(session), CorpsActif(actif: active)) }
    }

    public func changerModele(_ modele: String, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.modele(session), CorpsModele(modele: modele)) }
    }

    public func changerEffort(_ effort: String?, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.effort(session), CorpsEffort(effort: effort)) }
    }

    public func changerMode(_ mode: String, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.mode(session), CorpsMode(mode: mode)) }
    }

    public func basculerUltracode(_ actif: Bool, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.ultracode(session), CorpsActif(actif: actif)) }
    }

    public func renommer(_ titre: String, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.renommerSession(session), CorpsTitre(titre: titre)) }
    }

    public func arreterTache(_ tache: String, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.arreterTache(session, tache), Vide()) }
    }

    public func ouvrir(_ demande: DemandeOuverture) async -> Result<Session, ErreurRelais> {
        guard let client else { return .failure(.nonConnecte) }
        do {
            return .success(try await client.ouvrir(demande))
        } catch let erreur as ErreurRelais {
            return .failure(erreur)
        } catch {
            return .failure(.injoignable("\(error)"))
        }
    }

    public func contexte(de session: String) async -> Result<ContexteSession, ErreurRelais> {
        await lecture(Route.contexte(session))
    }

    public func taches(de session: String) async -> Result<[TacheSession], ErreurRelais> {
        await lecture(Route.taches(session))
    }

    public func environnements() async -> Result<[Environnement], ErreurRelais> {
        await lecture(Route.environnements)
    }

    public func marquerLues() async -> String? {
        guard let derniere = notifications.first?.seq else { return nil }
        return await executer { try await $0.ecrire(Route.notificationsLues, Jusqua(jusqua: derniere)) }
    }

    public func reveiller(_ machine: String) async -> String? {
        await executer { try await $0.ecrire(Route.reveiller(machine), Vide()) }
    }

    public func eteindre(_ machine: String) async -> String? {
        await executer { try await $0.ecrire(Route.eteindre(machine), Vide()) }
    }

    private func lecture<T: Decodable>(_ chemin: String) async -> Result<T, ErreurRelais> {
        guard let client else { return .failure(.nonConnecte) }
        do {
            let valeur: T = try await client.lire(chemin)
            return .success(valeur)
        } catch let erreur as ErreurRelais {
            return .failure(erreur)
        } catch {
            return .failure(.injoignable("\(error)"))
        }
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
