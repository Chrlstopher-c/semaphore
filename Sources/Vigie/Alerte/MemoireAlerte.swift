// Ce que la veille doit retenir d'un lancement à l'autre : le filigrane des notifications du relais déjà sonnées,
// et l'état du canal.
//
// `☠` Dans `UserDefaults`, pas dans le miroir : un réveil de fond doit pouvoir
// lire et réécrire ces quelques octets sans ouvrir, décoder puis réécrire tout
// l'instantané du parc. Mesuré : `UserDefaults` survit à un resignage.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

enum MemoireAlerte {

    private static let cleMemoire = "vigie.veille.filigrane.v2"

    static func lireMemoire() -> FiligraneRelais {
        guard let donnees = UserDefaults.standard.data(forKey: cleMemoire) else {
            return FiligraneRelais()
        }
        do {
            return try JSONDecoder().decode(FiligraneRelais.self, from: donnees)
        } catch {
            // Repartir de zéro sonne à nouveau ce qui est encore en attente —
            // bruyant mais sûr. L'inverse, sauter des faits, ne se voit jamais.
            Trace.erreur("alerte", "mémoire de veille illisible, repart de zéro", error)
            return FiligraneRelais()
        }
    }

    static func ecrire(_ memoire: FiligraneRelais) {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(memoire), forKey: cleMemoire)
        } catch {
            Trace.erreur("alerte", "mémoire de veille non persistée", error)
        }
    }

    static func lireEtat() -> EtatCanal {
        PreferencesAlerte.etatCanalConnu() ?? EtatCanal()
    }

    static func ecrire(_ etat: EtatCanal) {
        do {
            UserDefaults.standard.set(
                try JSONEncoder().encode(etat),
                forKey: PreferencesAlerte.cleEtatCanal
            )
        } catch {
            Trace.erreur("alerte", "état du canal non persisté", error)
        }
    }
}
#endif
