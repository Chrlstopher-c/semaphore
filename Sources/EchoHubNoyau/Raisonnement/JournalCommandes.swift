import Foundation

/// Le terminal de l'agent (`journal-commandes.ts` du web) : les commandes réellement lancées dans
/// l'atelier, relues dans les réponses du fil, avec leur sortie.
public struct CommandeJournal: Sendable, Equatable {
    public let commande: String
    public let sortie: String
    public let etat: EtatAppel
    public let python: Bool
}

public enum JournalCommandes {
    static let outilsShell: Set<String> = ["executer_commande", "run_command", "executer_python", "run_python", "serveur_fond"]

    /// `actif` : la dernière réponse est encore en train de s'écrire.
    public static func lire(_ contenus: [String], actif: Bool = false, limite: Int = 40) -> [CommandeJournal] {
        var lignes: [CommandeJournal] = []
        for (rang, contenu) in contenus.enumerated() {
            let enCours = actif && rang == contenus.count - 1
            for segment in SegmenteurReponse.segmenter(contenu).raisonnements where segment.convention == "outil" {
                guard let appel = LectureAppel.lire(segment.texte, actif: enCours && !segment.complet),
                      outilsShell.contains(appel.nom) else { continue }
                lignes.append(CommandeJournal(
                    commande: appel.cible ?? appel.entree.split(separator: "\n").first.map(String.init) ?? "",
                    sortie: appel.sortie, etat: appel.etat, python: appel.nom.contains("python")
                ))
            }
        }
        return Array(lignes.suffix(limite))
    }
}
