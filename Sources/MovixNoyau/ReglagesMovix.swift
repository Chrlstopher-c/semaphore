import Foundation

/// Ce que Chris règle pour le monde Movix : l'adresse de l'instance web à
/// charger. Par défaut l'instance servie en LAN — l'app trouve le site dès le
/// lancement sur le réseau local.
///
/// Noyau pur, testable sous Linux : la seule logique ici est la NORMALISATION
/// et la VALIDATION de l'adresse (préfixe de schéma implicite, host présent).
public struct ReglagesMovix: Sendable, Equatable, Codable {
    public var adresse: String

    public init(adresse: String) {
        self.adresse = adresse
    }

    /// L'instance LAN par défaut. Un simple `10.0.0.3:3000` sans schéma est
    /// accepté aussi (voir `url`) — mais le défaut porte le schéma pour l'exemple.
    public static let adresseParDefaut = "http://10.0.0.3:3000"

    public static let parDefaut = ReglagesMovix(adresse: adresseParDefaut)

    /// L'URL prête à charger. Un schéma manquant est comblé en `http://` (l'usage
    /// LAN typique : on tape une IP et un port, pas une URL complète). `nil` si,
    /// même comblée, l'adresse n'a pas de host exploitable.
    public var url: URL? {
        let brut = adresse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brut.isEmpty else { return nil }
        let avecSchema = brut.contains("://") ? brut : "http://\(brut)"
        guard let candidate = URL(string: avecSchema),
              candidate.scheme != nil,
              let host = candidate.host, !host.isEmpty
        else { return nil }
        return candidate
    }

    public var adresseValide: Bool { url != nil }
}
