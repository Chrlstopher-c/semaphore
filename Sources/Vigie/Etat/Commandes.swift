// Ce que Chris fait depuis Vigie — parler à une session, la piloter, en ouvrir une, agir sur le parc.
// Chaque commande rend l'erreur à afficher, ou nil. L'état qui en découle revient par le flux, sans rechargement.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

extension ModeleRelais {
    private struct Jusqua: Encodable { let jusqua: Int }

    /// Comme Lanterne : les écritures vont à la jumelle Remote Control d'une fiche de poste quand elle existe.
    public func cibleEcriture(_ session: String) -> String { JumellesDistantes.ecriture(session, sessions) }

    /// Comme Lanterne : on lit le fil de la fiche de poste d'une session Remote Control quand elle existe.
    public func sourceLecture(_ session: String) -> String { JumellesDistantes.lecture(session, sessions) }

    public func envoyer(_ texte: String, pieces: [PieceJointe] = [], a session: String) async -> String? {
        let corps = CorpsMessage(texte: texte, pieces: pieces)
        let cible = cibleEcriture(session)
        let lu = sourceLecture(session)
        envois[lu, default: []].append(texte)
        let erreur = await executer { try await $0.ecrire(Route.messages(cible), corps) }
        if erreur != nil { retirerEnvoi(texte, de: lu) } else { rattraperApresEnvoi() }
        return erreur
    }

    /// Filet sous le flux : après un envoi, les fils affichés sont relus par interrogation, à intervalles croissants,
    /// tant que la réponse n'est pas revenue. Sans flux (ou flux coupé), c'est le seul chemin qui ramène la réponse.
    private func rattraperApresEnvoi() {
        Task { [weak self] in
            for delai in [2, 5, 12, 25] {
                try? await Task.sleep(for: .seconds(delai))
                await self?.rattraperFils()
            }
        }
    }

    /// Le message est revenu dans le fil (ou l'envoi a échoué) : la bulle optimiste s'efface.
    func retirerEnvoi(_ texte: String, de fil: String) {
        guard var liste = envois[fil], let i = liste.firstIndex(of: texte) ?? liste.indices.first else { return }
        liste.remove(at: i)
        envois[fil] = liste.isEmpty ? nil : liste
    }

    /// Pilotage (interrompre, compacter, fermer, reprendre) : à la cible d'écriture. Rangement (archiver, épingler,
    /// lue / non lue) : à la fiche montrée, celle que Lanterne épingle aussi.
    public func agir(_ action: ActionSession, sur session: String) async -> String? {
        let pilotage: Set<ActionSession> = [.interrompre, .compacter, .fermer, .reprendre]
        let cible = pilotage.contains(action) ? cibleEcriture(session) : session
        return await executer { try await $0.ecrire(Route.action(cible, action), Vide()) }
    }

    public func interrompre(_ session: String) async -> String? {
        await agir(.interrompre, sur: session)
    }

    public func repondre(_ reponse: ReponseDialogue, a session: String) async -> String? {
        await executer { try await $0.ecrire(Route.repondre(cibleEcriture(session)), reponse) }
    }

    public func basculerAutonomie(_ active: Bool, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.autonomie(session), CorpsActif(actif: active)) }
    }

    public func changerModele(_ modele: String, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.modele(cibleEcriture(session)), CorpsModele(modele: modele)) }
    }

    public func changerEffort(_ effort: String?, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.effort(cibleEcriture(session)), CorpsEffort(effort: effort)) }
    }

    public func changerMode(_ mode: String, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.mode(cibleEcriture(session)), CorpsMode(mode: mode)) }
    }

    public func basculerUltracode(_ actif: Bool, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.ultracode(cibleEcriture(session)), CorpsActif(actif: actif)) }
    }

    public func renommer(_ titre: String, de session: String) async -> String? {
        await executer { try await $0.ecrire(Route.renommerSession(cibleEcriture(session)), CorpsTitre(titre: titre)) }
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
            return .failure(.injoignable(error.localizedDescription))
        }
    }

    /// `nil` : le nœud n'a pas de détail pour cette session (non pilotée par le SDK, pas encore lu) — rien à montrer.
    public func contexte(de session: String) async -> Result<ContexteSession?, ErreurRelais> {
        await lire(Route.contexte(session))
    }

    public func taches(de session: String) async -> Result<[TacheSession], ErreurRelais> {
        await lire(Route.taches(session))
    }

    public func environnements() async -> Result<[Environnement], ErreurRelais> {
        await lire(Route.environnements)
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

    func lire<T: Decodable>(_ chemin: String) async -> Result<T, ErreurRelais> {
        guard let client else { return .failure(.nonConnecte) }
        do {
            let valeur: T = try await client.lire(chemin)
            return .success(valeur)
        } catch let erreur as ErreurRelais {
            return .failure(erreur)
        } catch {
            return .failure(.injoignable(error.localizedDescription))
        }
    }

    private func executer(_ f: (ClientRelais) async throws -> Vide) async -> String? {
        guard let client else { return ErreurRelais.nonConnecte.description }
        do {
            _ = try await f(client)
            return nil
        } catch {
            Trace.erreur("relais", "commande refusée", error)
            return (error as? ErreurRelais)?.description ?? "Commande refusée par le nœud."
        }
    }
}
#endif
