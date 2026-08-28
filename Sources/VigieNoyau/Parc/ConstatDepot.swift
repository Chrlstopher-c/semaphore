import Foundation

/// L'état du dépôt d'une équipe au dernier relevé — l'information qui distingue
/// une équipe qui a LIVRÉ d'une équipe qui a seulement fini de parler.
///
/// `☠` Trois cas, jamais deux. `git == nil` n'est PAS « propre » : c'est
/// « jamais mesuré ». Peindre « propre » sur une absence de mesure ferait fermer
/// un worktree en croyant ne rien perdre — c'est exactement le mensonge retiré
/// du harness le 02/08, et le projet l'a payé cher.
public enum ConstatDepot: Sendable, Hashable {
    case jamaisReleve
    case propre(Releve)
    case travailNonCommite(fichiers: Int, releve: Releve)

    /// Ce que le relevé porte en plus du décompte.
    public struct Releve: Sendable, Hashable {
        public let branche: String?
        public let dernierCommit: String?
        /// Epoch ms du relevé. `☠` Toujours affiché avec l'état : un dépôt
        /// « propre » mesuré il y a quarante minutes ne dit rien du dépôt
        /// maintenant.
        public let a: Int

        public init(branche: String?, dernierCommit: String?, a: Int) {
            self.branche = branche
            self.dernierCommit = dernierCommit
            self.a = a
        }
    }

    public static func lire(_ constat: ConstatGitApi?) -> ConstatDepot {
        guard let constat else { return .jamaisReleve }
        let releve = Releve(
            branche: constat.branch.flatMap { $0.isEmpty ? nil : $0 },
            dernierCommit: constat.lastCommit.flatMap { $0.isEmpty ? nil : $0 },
            a: constat.at
        )
        guard constat.uncommitted > 0 else { return .propre(releve) }
        return .travailNonCommite(fichiers: constat.uncommitted, releve: releve)
    }

    /// La valeur montrée en tuile. Le mot remplace le chiffre quand il n'y a
    /// pas eu de mesure : « 0 » se lirait « rien à perdre ».
    public var valeur: String {
        switch self {
        case .jamaisReleve: return "non relevé"
        case .propre: return "propre"
        case .travailNonCommite(let fichiers, _):
            return "\(fichiers) non commité\(fichiers > 1 ? "s" : "")"
        }
    }

    /// La phrase de la carte du parc — vide quand il n'y a rien à signaler.
    public var avertissement: String? {
        guard case .travailNonCommite(let fichiers, let releve) = self else { return nil }
        let pluriel = fichiers > 1 ? "s" : ""
        guard let branche = releve.branche else {
            return "\(fichiers) fichier\(pluriel) non commité\(pluriel)"
        }
        return "\(fichiers) fichier\(pluriel) non commité\(pluriel) sur \(branche)"
    }

    public var releve: Releve? {
        switch self {
        case .jamaisReleve: return nil
        case .propre(let releve): return releve
        case .travailNonCommite(_, let releve): return releve
        }
    }

    /// Du travail est-il PERDABLE ? La seule chose que l'état du dépôt change à
    /// la décision de fermer une équipe.
    public var travailEnJeu: Bool {
        if case .travailNonCommite = self { return true }
        return false
    }
}
