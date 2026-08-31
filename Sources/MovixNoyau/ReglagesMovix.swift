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

    /// L'instance LAN par défaut. Une adresse sans schéma est
    /// accepté aussi (voir `url`) — mais le défaut porte le schéma pour l'exemple.
    public static let adresseParDefaut = adresseEmbarquee(
        "EchoAdresseMovix", repli: "http://10.0.0.2:3000")

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

/// Lit une adresse posée dans `Info.plist` au moment de compiler.
///
/// `☠` Le dépôt est public : aucune adresse réelle n'y est écrite. `build.sh`
/// génère `.build/Info.plist` depuis `Info.template.plist` en y injectant les
/// valeurs de `.env.local`, jamais suivi par git. Clé absente ou vide — clone
/// frais, suite de tests — on rend le repli, qui est un exemple.
func adresseEmbarquee(_ cle: String, repli: String) -> String {
    guard let brut = Bundle.main.object(forInfoDictionaryKey: cle) as? String else { return repli }
    let nettoyee = brut.trimmingCharacters(in: .whitespacesAndNewlines)
    return nettoyee.isEmpty ? repli : nettoyee
}
