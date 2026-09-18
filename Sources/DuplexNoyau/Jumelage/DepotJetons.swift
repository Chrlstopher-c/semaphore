import Foundation

/// Où sont gardés les jetons de jumelage, indexés par l'id du PC (16 hex du
/// TXT mDNS). Un double en mémoire reste possible pour les tests, sans toucher
/// au disque.
public protocol MagasinJetons: Sendable {
    func jeton(poste: String) -> String?
    func conserver(jeton: String, poste: String)
    func oublier(poste: String)
}

/// Le magasin réel : un JSON dans le dossier fourni.
///
/// `☠` Le fichier porte des secrets — un jeton suffit à écouter le PC de Chris.
/// Écrit avec la protection complète d'iOS : illisible tant que l'appareil n'a
/// pas été déverrouillé au moins une fois depuis le démarrage. Une lecture ou
/// une écriture ratée se journalise et retombe sur un état sûr — jamais un
/// crash pour un jeton.
public struct MagasinJetonsDisque: MagasinJetons {
    private let fichier: URL

    public init(dossier: URL) {
        self.fichier = dossier.appendingPathComponent("jetons-duplex.json")
    }

    public func jeton(poste: String) -> String? {
        tout()[poste]
    }

    public func conserver(jeton: String, poste: String) {
        var table = tout()
        table[poste] = jeton
        ecrire(table)
    }

    public func oublier(poste: String) {
        var table = tout()
        table.removeValue(forKey: poste)
        ecrire(table)
    }

    private func tout() -> [String: String] {
        guard let donnees = try? Data(contentsOf: fichier) else { return [:] }
        do {
            return try JSONDecoder().decode([String: String].self, from: donnees)
        } catch {
            Journal.echec("jetons illisibles, on repart de zéro : \(error)")
            return [:]
        }
    }

    private func ecrire(_ table: [String: String]) {
        do {
            try FileManager.default.createDirectory(
                at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder().encode(table).write(to: fichier, options: Self.protection)
        } catch {
            Journal.echec("échec d'écriture des jetons : \(error)")
        }
    }

    #if os(iOS)
    private static let protection: Data.WritingOptions = [.atomic, .completeFileProtection]
    #else
    private static let protection: Data.WritingOptions = [.atomic]
    #endif
}

/// Le magasin de test : tout en mémoire, rien sur le disque.
public final class MagasinJetonsMemoire: MagasinJetons, @unchecked Sendable {
    private var table: [String: String]
    private let verrou = NSLock()

    public init(_ table: [String: String] = [:]) {
        self.table = table
    }

    public func jeton(poste: String) -> String? {
        verrou.withLock { table[poste] }
    }

    public func conserver(jeton: String, poste: String) {
        verrou.withLock { table[poste] = jeton }
    }

    public func oublier(poste: String) {
        _ = verrou.withLock { table.removeValue(forKey: poste) }
    }
}
