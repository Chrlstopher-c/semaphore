import Foundation

// Responsabilité : les requêtes de l'API clients en vol, indexées par référence. Une réponse arrivée avant
// l'attente est gardée ; seule une référence déclarée reçoit un résultat ; un lien coupé échoue tout.

/// Réponse d'une requête de l'API clients, telle que le nœud l'a servie.
public struct ReponseRequete: Equatable, Sendable {
    public let statut: Int
    /// Texte, ou base64 quand `codage` vaut `base64` (corps binaire de type `type`).
    public let corps: String
    public var codage: String?
    public var type: String?

    public init(statut: Int, corps: String, codage: String? = nil, type: String? = nil) {
        self.statut = statut
        self.corps = corps
        self.codage = codage
        self.type = type
    }
}

actor TableRequetes {
    private var prevues: Set<String> = []
    private var attentes: [String: CheckedContinuation<ReponseRequete, Error>] = [:]
    private var resultats: [String: Result<ReponseRequete, Error>] = [:]

    /// Déclare une requête en vol : sans déclaration, aucun résultat n'est retenu pour cette référence.
    func prevoir(_ ref: String) {
        prevues.insert(ref)
    }

    /// Retire une requête qui n'a pas pu partir.
    func annuler(_ ref: String) {
        prevues.remove(ref)
        resultats.removeValue(forKey: ref)
    }

    func resoudre(_ ref: String, _ reponse: ReponseRequete) {
        deposer(ref, .success(reponse))
    }

    func echouer(_ ref: String, _ erreur: Error) {
        deposer(ref, .failure(erreur))
    }

    /// Lien coupé : toutes les requêtes en vol échouent avec la même erreur.
    func echouerTout(_ erreur: Error) {
        for ref in prevues {
            deposer(ref, .failure(erreur))
        }
    }

    /// Attend le résultat d'une requête déclarée ; un résultat déjà arrivé est rendu sans attendre.
    func attendre(_ ref: String) async throws -> ReponseRequete {
        if let resultat = resultats.removeValue(forKey: ref) {
            return try resultat.get()
        }
        return try await withCheckedThrowingContinuation { attentes[ref] = $0 }
    }

    private func deposer(_ ref: String, _ resultat: Result<ReponseRequete, Error>) {
        guard prevues.remove(ref) != nil else { return }
        if let attente = attentes.removeValue(forKey: ref) {
            attente.resume(with: resultat)
        } else {
            resultats[ref] = resultat
        }
    }
}
