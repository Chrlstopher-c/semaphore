// Le fil d'une session côté modèle : premier chargement, page plus ancienne, rattrapage après coupure, relecture
// quand le relais signale un fil modifié. Les écritures passent par ModeleRelais.swift.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

extension ModeleRelais {
    /// Taille du premier chargement d'un fil, puis d'une page plus ancienne.
    static let tailleDebutFil = 300
    static let taillePageFil = 200

    /// Charge le fil, puis le tient tant que la tâche vit (l'écran est visible). La suite arrive par le flux, ou par
    /// le long-poll de repli. Le fil est libéré à la fin de la tâche.
    public func suivreFil(_ id: String) async {
        await chargerDebut(id)
        try? await Task.sleep(for: .seconds(86_400))
        retirerFil(id)
    }

    /// Ajoute la page d'événements qui précède le premier événement chargé.
    public func chargerPlusAncien(_ id: String) async {
        guard let client, !debutAtteint.contains(id), let premier = fils[id]?.first?.seq else { return }
        do {
            let page: [EvenementDate] = try await client.lire(Route.evenementsAvant(id, avant: premier,
                                                                                    limite: Self.taillePageFil))
            fusionnerFil(id, page, atteint: page.count < Self.taillePageFil)
        } catch {
            Trace.erreur("relais", "page ancienne du fil \(id) non chargée", error)
        }
    }

    private func chargerDebut(_ id: String) async {
        guard let client else { return }
        do {
            let evenements: [EvenementDate] = try await client.lire(Route.evenements(id))
            fusionnerFil(id, evenements, atteint: evenements.count < Self.tailleDebutFil)
        } catch {
            Trace.erreur("relais", "fil \(id) non chargé", error)
        }
    }

    /// Après une coupure ou un changement de nœud : relit la suite de chaque fil chargé, depuis son dernier `seq`.
    /// Un autre nœud numérote ses fils autrement : si la source d'un fil a changé, ce fil est relu en entier.
    func rattraperFils() async {
        guard let client else { return }
        for (id, fil) in fils {
            let origine = await client.origineNumerotation(session: id)
            if origine != origineDesFils[id] {
                guard await relireFil(id) else { continue }
                origineDesFils[id] = origine
                continue
            }
            guard let dernier = fil.last else { continue }
            await rattraperFil(client, id, depuis: dernier)
        }
    }

    private func rattraperFil(_ client: ClientRelais, _ id: String, depuis dernier: EvenementDate) async {
        do {
            let suite: [EvenementDate] = try await client.lire(Route.evenements(id, apres: dernier.seq, attendre: 0))
            if suite.isEmpty {
                await verifierCurseur(client, id, dernier)
            } else if fils[id] != nil {
                fusionnerFil(id, suite, atteint: false)
            }
            // Le tour est fini (vu par la relecture avant le flux) : plus rien ne s'écrit en direct.
            if case .tourFini = suite.last?.evt {
                viderTexte(id)
                viderReflexion(id)
            }
        } catch {
            Trace.erreur("relais", "rattrapage du fil \(id) impossible", error)
        }
    }

    /// Suite vide alors que la session a bougé depuis le dernier événement connu : le relais est peut-être derrière
    /// le curseur (fil renuméroté). On le vérifie sur le fil complet ; sans ce même événement, on relit tout.
    private func verifierCurseur(_ client: ClientRelais, _ id: String, _ dernier: EvenementDate) async {
        guard let majLe = session(id)?.majLe,
              CurseurFil.sessionPlusRecente(majLe: majLe, que: dernier.ts) else { return }
        do {
            let complet: [EvenementDate] = try await client.lire(Route.evenements(id))
            guard fils[id] != nil, !CurseurFil.coherent(dernier, avec: complet) else { return }
            Trace.info("relais", "fil \(id) : le relais n'a plus le dernier événement connu, relecture complète")
            remplacerFil(id, complet, atteint: complet.count < Self.tailleDebutFil)
        } catch {
            Trace.erreur("relais", "contrôle du curseur du fil \(id) impossible", error)
        }
    }


    /// Le relais a réécrit ce fil : on le relit en entier, s'il est encore chargé. Rend vrai si le fil est à jour.
    @discardableResult
    func relireFil(_ id: String) async -> Bool {
        guard let client, fils[id] != nil else { return true }
        do {
            let evenements: [EvenementDate] = try await client.lire(Route.evenements(id))
            remplacerFil(id, evenements, atteint: evenements.count < Self.tailleDebutFil)
            return true
        } catch {
            Trace.erreur("relais", "relecture du fil \(id) impossible", error)
            return false
        }
    }
}
#endif
