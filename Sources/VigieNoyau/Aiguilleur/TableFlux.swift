import Foundation

// Responsabilité : les réponses en flux de l'API clients (requête `?flux=1`) en vol, indexées par référence. L'en-tête
// (statut, type) rend le flux à l'appelant ; ses morceaux (base64) sortent au fil de leur arrivée ; `api_fin` le
// referme, en erreur si la fin annoncée ou l'ordre des morceaux ne tombent pas juste. Une réponse entière (nœud qui
// ne streame pas) rend aussi un flux, d'un seul bloc. Seule une référence déclarée reçoit quelque chose.

/// Réponse en flux : statut et type, puis les octets au fil de leur arrivée.
public struct ReponseFlux: Sendable {
    public let statut: Int
    public let type: String?
    public let octets: AsyncThrowingStream<Data, Error>
}

actor TableFlux {
    /// Une requête déclarée dont l'en-tête n'est pas encore arrivé : son flux de sortie attend son en-tête.
    private struct EnAttenteEntete {
        let octets: AsyncThrowingStream<Data, Error>
        let sortie: AsyncThrowingStream<Data, Error>.Continuation
    }

    /// Un flux dont l'en-tête est arrivé : ses morceaux suivent, dans l'ordre de leur rang.
    private struct EnRoute {
        let sortie: AsyncThrowingStream<Data, Error>.Continuation
        var rangAttendu: Int
    }

    private var declarees: [String: EnAttenteEntete] = [:]
    private var entetes: [String: CheckedContinuation<ReponseFlux, Error>] = [:]
    private var resultats: [String: Result<ReponseFlux, Error>] = [:]
    private var enRoute: [String: EnRoute] = [:]

    /// Déclare une requête avant son envoi : son flux de sortie existe dès maintenant.
    func prevoir(_ ref: String) {
        let (octets, sortie) = AsyncThrowingStream.makeStream(of: Data.self)
        declarees[ref] = EnAttenteEntete(octets: octets, sortie: sortie)
    }

    /// Retire une requête qui n'a pas pu partir.
    func annuler(_ ref: String) {
        declarees.removeValue(forKey: ref)?.sortie.finish()
        resultats.removeValue(forKey: ref)
    }

    /// Attend l'en-tête (ou la réponse entière) d'une requête déclarée ; un résultat déjà arrivé est rendu aussitôt.
    func attendre(_ ref: String) async throws -> ReponseFlux {
        if let resultat = resultats.removeValue(forKey: ref) { return try resultat.get() }
        guard declarees[ref] != nil else { throw ErreurAiguilleur("requête de flux inconnue") }
        return try await withCheckedThrowingContinuation { entetes[ref] = $0 }
    }

    /// L'en-tête d'un flux : il rend la réponse à l'appelant. Une référence non déclarée est ignorée (faux).
    func ouvrir(_ ref: String, statut: Int, type: String?) -> Bool {
        guard let attente = declarees.removeValue(forKey: ref) else { return false }
        enRoute[ref] = EnRoute(sortie: attente.sortie, rangAttendu: 0)
        livrer(ref, .success(ReponseFlux(statut: statut, type: type, octets: attente.octets)))
        return true
    }

    /// Un morceau d'un flux ouvert : son rang doit suivre le précédent ; faux si la référence n'est pas en flux.
    func morceau(_ ref: String, rang: Int, base64: String) -> Bool {
        guard var courant = enRoute[ref] else { return false }
        guard rang == courant.rangAttendu, let octets = Data(base64Encoded: base64) else {
            enRoute.removeValue(forKey: ref)
            courant.sortie.finish(throwing: ErreurAiguilleur("morceau de flux hors ordre ou illisible"))
            return true
        }
        courant.sortie.yield(octets)
        courant.rangAttendu += 1
        enRoute[ref] = courant
        return true
    }

    /// Une réponse entière à une requête déclarée : un flux d'un seul bloc. Faux si la référence n'est pas déclarée.
    func entier(_ ref: String, statut: Int, type: String?, octets: Data) -> Bool {
        guard let attente = declarees.removeValue(forKey: ref) else { return false }
        if !octets.isEmpty { attente.sortie.yield(octets) }
        attente.sortie.finish()
        livrer(ref, .success(ReponseFlux(statut: statut, type: type, octets: attente.octets)))
        return true
    }

    /// La fin d'un flux : réussie seulement si `morceaux` morceaux sont arrivés dans l'ordre et que le nœud dit ok.
    func fin(_ ref: String, morceaux: Int, ok: Bool) {
        guard let courant = enRoute.removeValue(forKey: ref) else { return }
        if ok && courant.rangAttendu == morceaux {
            courant.sortie.finish()
        } else {
            courant.sortie.finish(throwing: ErreurAiguilleur("flux interrompu"))
        }
    }

    /// Délai de l'en-tête dépassé : seule une requête encore sans en-tête échoue (un flux en cours n'est pas coupé).
    func echouer(_ ref: String, _ erreur: Error) {
        guard let attente = declarees.removeValue(forKey: ref) else { return }
        attente.sortie.finish(throwing: erreur)
        livrer(ref, .failure(erreur))
    }

    /// Lien coupé : les requêtes sans en-tête échouent, les flux en cours se referment en erreur.
    func echouerTout(_ erreur: Error) {
        for ref in Array(declarees.keys) { echouer(ref, erreur) }
        for (ref, courant) in enRoute {
            enRoute.removeValue(forKey: ref)
            courant.sortie.finish(throwing: erreur)
        }
    }

    private func livrer(_ ref: String, _ resultat: Result<ReponseFlux, Error>) {
        if let attente = entetes.removeValue(forKey: ref) {
            attente.resume(with: resultat)
        } else {
            resultats[ref] = resultat
        }
    }
}
