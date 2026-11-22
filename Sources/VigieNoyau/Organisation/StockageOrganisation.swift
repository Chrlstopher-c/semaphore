import Foundation

// Responsabilité : la lecture et l'écriture durables de l'organisation de l'iPhone (un fichier JSON versionné, dans le
// conteneur de l'appli). Lu au démarrage, avant tout réseau. Écriture atomique : un échec laisse la version précédente.
// Un fichier illisible ou d'une version plus récente est mis de côté (`.illisible`), jamais écrasé en silence.

public struct StockageOrganisation: Sendable {
    public let fichier: URL

    public init(fichier: URL) {
        self.fichier = fichier
    }

    /// `organisation.json` dans le dossier de support de l'appli ; à défaut le dossier temporaire (journalisé).
    public static func parDefaut() -> StockageOrganisation {
        let racine: URL
        do {
            racine = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            Trace.erreur("organisation", "dossier de support introuvable, repli temporaire", error)
            racine = FileManager.default.temporaryDirectory
        }
        return StockageOrganisation(fichier: racine.appendingPathComponent("organisation.json"))
    }

    /// L'organisation gardée ; vide tant que rien n'est écrit.
    public func lire() -> Organisation {
        guard FileManager.default.fileExists(atPath: fichier.path) else { return .vide }
        do {
            let donnees = try Data(contentsOf: fichier)
            let organisation = try JSONDecoder().decode(Organisation.self, from: donnees)
            guard organisation.version <= Organisation.versionCourante else {
                throw ErreurOrganisation.versionPlusRecente(organisation.version)
            }
            return organisation
        } catch {
            mettreDeCote(error)
            return .vide
        }
    }

    /// Écrit l'organisation. Rend false (journalisé) si l'écriture échoue ; le fichier précédent reste en place.
    @discardableResult
    public func ecrire(_ organisation: Organisation) -> Bool {
        do {
            let donnees = try JSONEncoder().encode(organisation)
            try donnees.write(to: fichier, options: .atomic)
            return true
        } catch {
            Trace.erreur("organisation", "écriture impossible, la version précédente reste", error)
            return false
        }
    }

    private func mettreDeCote(_ cause: Error) {
        let cote = fichier.appendingPathExtension("illisible")
        do {
            if FileManager.default.fileExists(atPath: cote.path) {
                try FileManager.default.removeItem(at: cote)
            }
            try FileManager.default.moveItem(at: fichier, to: cote)
            Trace.erreur("organisation", "fichier illisible mis de côté (\(cote.lastPathComponent))", cause)
        } catch {
            Trace.erreur("organisation", "fichier illisible, mise de côté impossible", error)
        }
    }
}

enum ErreurOrganisation: Error {
    case versionPlusRecente(Int)
}
