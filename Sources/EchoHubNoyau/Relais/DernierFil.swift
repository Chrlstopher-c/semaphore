import Foundation

/// Le seul identifiant de la dernière conversation ouverte, gardé entre deux
/// lancements.
///
/// `☠` Ce n'est PAS une entorse à « aucune persistance locale »
/// (`ARCHITECTURE.md`). Cette règle interdit de garder du CONTENU, parce que
/// deux bases qui divergent est le seul vrai piège d'une app de chat
/// multi-appareils. Un identifiant n'est pas du contenu : il ne peut pas
/// diverger, et le fil qu'il désigne est relu au serveur à chaque ouverture.
///
/// Ce qu'il évite : chaque lancement tombait sur « Aucune conversation » dans
/// l'onglet où l'on vit, et imposait un détour par l'onglet Conversations. Sur
/// une app qu'on ouvre vingt fois par jour, c'était le geste le plus répété du
/// produit.
public struct MemoireDernierFil: Sendable {
    private let fichier: URL

    public init(dossier: URL) {
        self.fichier = dossier.appendingPathComponent("dernier-fil.json")
    }

    private struct Contenu: Codable {
        let conversationId: String
    }

    public func lire() -> String? {
        guard let donnees = try? Data(contentsOf: fichier) else { return nil }
        do {
            return try JSONDecoder().decode(Contenu.self, from: donnees).conversationId
        } catch {
            Journal.echec("dernier fil illisible, on repart de zéro : \(error)")
            return nil
        }
    }

    public func ecrire(_ identifiant: String?) {
        guard let identifiant else { return effacer() }
        do {
            let donnees = try JSONEncoder().encode(Contenu(conversationId: identifiant))
            try FileManager.default.createDirectory(
                at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try donnees.write(to: fichier, options: .atomic)
        } catch {
            Journal.echec("dernier fil non enregistré : \(error)")
        }
    }

    private func effacer() {
        do {
            try FileManager.default.removeItem(at: fichier)
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            Journal.echec("dernier fil non effacé : \(error)")
        }
    }
}
