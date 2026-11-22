import Foundation

// Responsabilité : le titre montré d'une session. Le relais nomme une session adoptée sans nom d'après son dossier
// (« trinity » pour le dossier personnel) : ce n'est pas un titre. Comme l'étalon, on montre alors le début de la
// première demande, sinon l'objectif, sinon « Sans titre ».

public enum TitreSession {
    public static let sansTitre = "Sans titre"
    static let longueurMax = 80

    /// Le titre du relais n'en est pas un : vide, nom du dossier, nom du projet, ou nom par défaut.
    public static func estDeRepli(_ s: Session) -> Bool {
        let titre = s.titre.trimmingCharacters(in: .whitespacesAndNewlines)
        if titre.isEmpty || titre == "Claude" || titre == "claude" { return true }
        let dossier = (s.cwd as NSString).lastPathComponent
        return titre == dossier || titre == s.projet.nom || titre == (s.projet.chemin as NSString).lastPathComponent
    }

    public static func affiche(_ s: Session, premierMessage: String?) -> String {
        guard estDeRepli(s) else { return s.titre }
        if let m = premierMessage.map(premiereLigne), !m.isEmpty { return m }
        if let o = s.objectif.map(premiereLigne), !o.isEmpty { return o }
        return sansTitre
    }

    /// La première ligne non vide, coupée à 80 caractères.
    public static func premiereLigne(_ texte: String) -> String {
        let ligne = texte.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        return ligne.count > longueurMax ? String(ligne.prefix(longueurMax - 1)) + "…" : ligne
    }

    /// Le texte du premier message de Chris dans un morceau de fil.
    public static func premierMessage(_ fil: [EvenementDate]) -> String? {
        for e in fil { if case .message(let texte, _, _) = e.evt { return texte } }
        return nil
    }
}
