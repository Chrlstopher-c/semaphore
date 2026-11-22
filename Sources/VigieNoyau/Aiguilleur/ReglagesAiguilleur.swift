import Foundation

// Responsabilité : le réglage « Passer par l'aiguilleur », à côté de l'appairage direct. Le transport choisit
// l'un ou l'autre selon ce réglage ; une adresse ou un code invalides ne l'activent jamais.

struct ReglagesAiguilleur: Codable, Equatable, Sendable {
    var passerParAiguilleur: Bool
    var adresse: String
    var code: String

    static let defaut = ReglagesAiguilleur(passerParAiguilleur: false, adresse: "", code: "")

    /// Adresse https (tunnel) ou http (réseau privé du VPN), avec un hôte.
    var adresseValide: Bool {
        guard let url = URL(string: adresse), let schema = url.scheme, let hote = url.host else { return false }
        return (schema == "https" || schema == "http") && !hote.isEmpty
    }

    /// Code d'appairage au format XXXX-XXXX (majuscules et chiffres), comme l'aiguilleur le délivre.
    var codeValide: Bool {
        code.range(of: "^[A-Z0-9]{4}-[A-Z0-9]{4}$", options: .regularExpression) != nil
    }

    /// Vrai seulement si le réglage est activé et complet : sinon le transport direct reste en place.
    var actif: Bool { passerParAiguilleur && adresseValide && codeValide }
}
