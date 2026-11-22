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

    /// Après une coupure : relit la suite de chaque fil chargé, depuis son dernier `seq`.
    func rattraperFils() async {
        guard let client else { return }
        for (id, fil) in fils {
            guard let apres = fil.last?.seq else { continue }
            do {
                let suite: [EvenementDate] = try await client.lire(Route.evenements(id, apres: apres, attendre: 0))
                if !suite.isEmpty, fils[id] != nil { fusionnerFil(id, suite, atteint: false) }
                // Le tour est fini (vu par la relecture avant le flux) : plus rien ne s'écrit en direct.
                if case .tourFini = suite.last?.evt {
                    viderTexte(id)
                    viderReflexion(id)
                }
            } catch {
                Trace.erreur("relais", "rattrapage du fil \(id) impossible", error)
            }
        }
    }

    /// Le relais a réécrit ce fil : on le relit en entier, s'il est encore chargé.
    func relireFil(_ id: String) async {
        guard let client, fils[id] != nil else { return }
        do {
            let evenements: [EvenementDate] = try await client.lire(Route.evenements(id))
            remplacerFil(id, evenements, atteint: evenements.count < Self.tailleDebutFil)
        } catch {
            Trace.erreur("relais", "relecture du fil \(id) impossible", error)
        }
    }
}
#endif
