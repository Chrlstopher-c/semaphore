import Foundation

/// Ce que Chris règle : l'adresse du serveur Saily et le jeton qui l'ouvre.
///
/// Même forme et même contrat d'échec que le `ReglagesRelais` d'EchoHub — c'est
/// le pattern éprouvé du dépôt. L'adresse par défaut pointe la PROD, déjà en
/// ligne : l'app trouve le serveur dès l'installation, et le champ dit par
/// l'exemple à quoi ressemble ce qu'on y colle.
public struct ReglagesServeur: Sendable, Equatable, Codable {
    public var adresse: String
    /// Secret partagé, envoyé en `Authorization: Bearer` (et en `?token=` pour
    /// le WebSocket). Vide = aucune authentification tentée.
    public var jeton: String

    public init(adresse: String, jeton: String) {
        self.adresse = adresse
        self.jeton = jeton
    }

    public static let adresseProdParDefaut = "https://saily.example.com"

    public static let parDefaut = ReglagesServeur(adresse: adresseProdParDefaut, jeton: "")

    /// Un schéma et un hôte suffisent ; port et chemin restent libres (le tunnel
    /// peut servir sur un sous-chemin).
    public var adresseValide: Bool {
        guard let url = URL(string: adresse) else { return false }
        return url.scheme != nil && url.host != nil
    }
}

/// Où garder le réglage — un double en mémoire reste possible pour les tests,
/// sans toucher au disque.
public protocol MagasinReglagesServeur: Sendable {
    func charger() -> ReglagesServeur
    func sauvegarder(_ reglages: ReglagesServeur)
}

/// Le magasin réel : un fichier JSON dans le dossier fourni.
///
/// `☠` Le fichier porte le jeton (un secret). Écrit avec la protection complète
/// d'iOS : illisible tant que l'appareil n'a pas été déverrouillé au moins une
/// fois depuis le démarrage. Une lecture/écriture ratée se journalise et
/// retombe sur un état sûr, jamais un crash pour un réglage.
public struct MagasinReglagesServeurDisque: MagasinReglagesServeur {
    private let fichier: URL

    public init(dossier: URL) {
        self.fichier = dossier.appendingPathComponent("reglages-serveur.json")
    }

    public func charger() -> ReglagesServeur {
        guard let donnees = try? Data(contentsOf: fichier) else { return .parDefaut }
        do {
            return try JSONDecoder().decode(ReglagesServeur.self, from: donnees)
        } catch {
            Journal.echec("réglages serveur illisibles, repli sur le défaut : \(error)")
            return .parDefaut
        }
    }

    public func sauvegarder(_ reglages: ReglagesServeur) {
        do {
            let donnees = try JSONEncoder().encode(reglages)
            try FileManager.default.createDirectory(
                at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try donnees.write(to: fichier, options: Self.protection)
        } catch {
            Journal.echec("échec d'écriture des réglages serveur : \(error)")
        }
    }

    #if os(iOS)
    private static let protection: Data.WritingOptions = [.atomic, .completeFileProtection]
    #else
    private static let protection: Data.WritingOptions = [.atomic]
    #endif
}

/// Charge et sauvegarde le réglage, hors du fil principal.
public actor GestionnaireReglagesServeur {
    private let magasin: any MagasinReglagesServeur
    private var enMemoire: ReglagesServeur?

    public init(magasin: any MagasinReglagesServeur) {
        self.magasin = magasin
    }

    public func actuels() -> ReglagesServeur {
        if let enMemoire { return enMemoire }
        let charges = magasin.charger()
        enMemoire = charges
        return charges
    }

    public func mettreAJour(_ reglages: ReglagesServeur) {
        enMemoire = reglages
        magasin.sauvegarder(reglages)
    }
}
