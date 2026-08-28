import Foundation

/// Le `clientId` de CET appareil : un identifiant stable, tiré une fois et
/// gardé.
///
/// `☠` Il doit survivre aux lancements, sinon le filtrage d'écho casse — le
/// serveur renvoie `origin` sur chaque diffusion, et c'est en le comparant à ce
/// clientId qu'on reconnaît ses propres écritures. Un id régénéré à chaque
/// démarrage rendrait tout écho méconnaissable.
public enum IdentiteClient {
    /// Lit l'id du disque, ou en crée un et l'écrit. Un échec d'écriture n'est
    /// pas fatal : on rend un id de session, journalisé, quitte à revoir ses
    /// propres échos jusqu'au prochain lancement réussi.
    public static func stable(dossier: URL) -> String {
        let fichier = dossier.appendingPathComponent("identite-client.txt")
        if let donnees = try? Data(contentsOf: fichier),
           let texte = String(data: donnees, encoding: .utf8),
           !texte.isEmpty {
            return texte
        }
        let neuf = "ios-" + UUID().uuidString
        do {
            try FileManager.default.createDirectory(
                at: dossier, withIntermediateDirectories: true
            )
            try Data(neuf.utf8).write(to: fichier, options: [.atomic])
        } catch {
            Journal.echec("identité client non persistée, id de session : \(error)")
        }
        return neuf
    }
}
