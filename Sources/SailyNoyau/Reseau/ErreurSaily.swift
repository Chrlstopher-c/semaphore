import Foundation

/// Ce qui peut rater entre l'iPhone et le serveur Saily, dit en français et
/// actionnable. Le message est destiné à être AFFICHÉ : il dit où la chaîne a
/// cassé — l'adresse, le jeton, le serveur — parce que ce ne sont pas les mêmes
/// réparations.
public enum ErreurSaily: Error, Sendable, Equatable {
    case adresseInvalide(String)
    case injoignable(String)
    /// Requête ANNULÉE localement (retour d'écran, tâche remplacée). Pas une
    /// panne : rien à réparer, rien à montrer.
    case annule
    /// Jeton refusé (401/403).
    case refuse
    /// Un refus non traité spécialement : on rend ce que le serveur a écrit.
    case serveur(statut: Int, message: String)
    case reponseIllisible(String)

    public var libelle: String {
        switch self {
        case .adresseInvalide(let adresse):
            return "Adresse de serveur invalide : « \(adresse) »."
        case .injoignable(let detail):
            return "Serveur injoignable — \(detail)"
        case .annule:
            return "Opération annulée."
        case .refuse:
            return "Jeton refusé par le serveur."
        case .serveur(let statut, let message):
            return message.isEmpty ? "Le serveur a répondu \(statut)." : message
        case .reponseIllisible(let detail):
            return "Réponse illisible : \(detail)"
        }
    }

    public var remede: String? {
        switch self {
        case .adresseInvalide, .injoignable:
            return "Vérifie l'adresse dans Réglages, et ta connexion."
        case .refuse:
            return "Vérifie le jeton dans Réglages."
        case .annule, .serveur, .reponseIllisible:
            return nil
        }
    }

    /// Une annulation locale — jamais une panne à montrer.
    public var estAnnulation: Bool {
        if case .annule = self { return true }
        return false
    }

    /// Reconnaît une annulation venue du réseau ou de la concurrence, AVANT
    /// traduction, pour lever `.annule` plutôt que `.injoignable`.
    public static func vientDUneAnnulation(_ erreur: Error) -> Bool {
        if erreur is CancellationError { return true }
        if let url = erreur as? URLError, url.code == .cancelled { return true }
        return false
    }

    /// Traduit un statut HTTP hors 2xx. Pur, éprouvable sans réseau.
    public static func depuisStatut(_ statut: Int, donnees: Data) -> ErreurSaily {
        if statut == 401 || statut == 403 { return .refuse }
        let message = messageServeur(donnees)
        return .serveur(statut: statut, message: message)
    }

    /// Le serveur écrit `{"error": "..."}` sur ses refus. On préfère toujours ce
    /// texte au libellé générique.
    static func messageServeur(_ donnees: Data) -> String {
        guard let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any],
              let texte = objet["error"] as? String else { return "" }
        return texte
    }
}
