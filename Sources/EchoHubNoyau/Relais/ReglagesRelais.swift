import Foundation

/// Ce que Chris règle depuis l'app : l'adresse du relais et le jeton qui
/// l'ouvre.
///
/// `☠` Deux adresses existent dans la vraie vie et l'app n'en devine aucune :
/// l'adresse locale (`http://10.0.0.2:8947`, rapide, valable à la maison)
/// et l'adresse du tunnel (HTTPS, valable partout). C'est un CHAMP, pas une
/// constante compilée, précisément parce que le nom du tunnel ne doit pas
/// vivre dans le dépôt — voir `TODO.md`, arbitrage sous-domaine.
public struct ReglagesRelais: Sendable, Equatable, Codable {
    public var adresse: String
    /// Le secret partagé avec le relais. Envoyé en `Authorization: Bearer`.
    /// Vide = aucune authentification tentée, ce qui n'a de sens que si le
    /// relais tourne sans jeton (développement en local, jamais exposé).
    public var jeton: String

    public init(adresse: String, jeton: String) {
        self.adresse = adresse
        self.jeton = jeton
    }

    /// Le premier lancement : l'adresse locale du Pi, aucun jeton.
    ///
    /// Pourquoi une adresse pré-remplie plutôt qu'un champ vide — c'est le choix
    /// de Sillon et il s'est vérifié à l'usage : l'app trouve le relais dès
    /// l'installation quand on est chez soi, et le champ dit par l'exemple à
    /// quoi doit ressembler ce qu'on y colle.
    public static let parDefaut = ReglagesRelais(adresse: adresseLocaleParDefaut, jeton: "")

    public static let adresseLocaleParDefaut = "http://10.0.0.2:8947"

    /// Une adresse utilisable : un schéma et un hôte. Le reste — port, chemin —
    /// est laissé libre : un tunnel peut très bien servir sur un sous-chemin.
    public var adresseValide: Bool {
        guard let url = URL(string: adresse) else { return false }
        return url.scheme != nil && url.host != nil
    }
}

/// Ce que le gestionnaire attend d'un endroit où garder le réglage — un double
/// en mémoire reste possible pour les tests, sans toucher au disque.
public protocol MagasinReglagesRelais: Sendable {
    func charger() -> ReglagesRelais
    func sauvegarder(_ reglages: ReglagesRelais)
}

/// Le magasin réel : un fichier JSON dans le dossier fourni.
///
/// `☠` Le fichier porte un SECRET (le jeton). Il est écrit avec la protection
/// complète d'iOS : illisible tant que l'appareil n'a pas été déverrouillé au
/// moins une fois depuis le démarrage. Le trousseau ferait mieux, mais y
/// accéder demande un entitlement, et l'app est signée en provisioning gratuit
/// — voir `TODO.md`, arbitrage trousseau.
///
/// Même contrat d'échec que les magasins disque de Sillon : une lecture ou une
/// écriture ratée se journalise et retombe sur un état sûr, jamais un crash
/// pour un réglage.
public struct MagasinReglagesRelaisDisque: MagasinReglagesRelais {
    private let fichier: URL

    public init(dossier: URL) {
        self.fichier = dossier.appendingPathComponent("reglages-relais.json")
    }

    public func charger() -> ReglagesRelais {
        guard let donnees = try? Data(contentsOf: fichier) else { return .parDefaut }
        do {
            return try JSONDecoder().decode(ReglagesRelais.self, from: donnees)
        } catch {
            Journal.echec("réglages relais illisibles, repli sur le défaut : \(error)")
            return .parDefaut
        }
    }

    public func sauvegarder(_ reglages: ReglagesRelais) {
        do {
            let donnees = try JSONEncoder().encode(reglages)
            try FileManager.default.createDirectory(
                at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try donnees.write(to: fichier, options: Self.protection)
        } catch {
            Journal.echec("échec d'écriture des réglages relais : \(error)")
        }
    }

    #if os(iOS)
    private static let protection: Data.WritingOptions = [.atomic, .completeFileProtection]
    #else
    private static let protection: Data.WritingOptions = [.atomic]
    #endif
}

/// Charge et sauvegarde le réglage, hors du fil principal.
public actor GestionnaireReglagesRelais {
    private let magasin: any MagasinReglagesRelais
    private var enMemoire: ReglagesRelais?

    public init(magasin: any MagasinReglagesRelais) {
        self.magasin = magasin
    }

    public func actuels() -> ReglagesRelais {
        if let enMemoire { return enMemoire }
        let charges = magasin.charger()
        enMemoire = charges
        return charges
    }

    public func mettreAJour(_ reglages: ReglagesRelais) {
        enMemoire = reglages
        magasin.sauvegarder(reglages)
    }
}
