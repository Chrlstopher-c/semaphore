import Foundation

/// Nettoie une capture de panneau tmux avant affichage.
///
/// `☠` La SPA se contente de `/\x1B\[[0-9;]*[mGKHF]/g`, qui ne couvre que cinq
/// lettres finales sur les soixante-trois possibles. Tout le reste — masquage du
/// curseur `\x1B[?25l`, réglages de mode, séquences OSC de titre de fenêtre —
/// traverse et s'affiche en clair au milieu du texte. Un TUI comme Claude Code en
/// émet à chaque rafraîchissement : c'est la première chose qui rend le terminal
/// de la webapp illisible sur téléphone.
public enum EpurationAnsi {

    private static let echappement: Character = "\u{1B}"
    private static let cloche: Character = "\u{07}"

    /// Retire les séquences d'échappement, applique les retours chariot et
    /// supprime les lignes vides de fin. Le résultat est du texte affichable tel
    /// quel dans une vue monospacée.
    public static func epurer(_ brut: String) -> String {
        let sansSequences = retirerSequences(brut)
        let lignes = sansSequences
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { appliquerRetourChariot(String($0)) }
        return String(rognerFin(lignes).joined(separator: "\n"))
    }

    /// Automate minimal : on ne cherche pas à interpréter les séquences, juste à
    /// les consommer jusqu'à leur octet final, qui seul dit où elles s'arrêtent.
    private static func retirerSequences(_ brut: String) -> String {
        var sortie = ""
        sortie.reserveCapacity(brut.count)
        var reste = Substring(brut)
        while let debut = reste.firstIndex(of: echappement) {
            sortie += reste[reste.startIndex..<debut]
            let apres = reste.index(after: debut)
            reste = reste[apres...]
            reste = consommer(reste)
        }
        sortie += reste
        return sortie.filter { $0 == "\n" || $0 == "\t" || $0 == "\r" || !$0.isControleC0 }
    }

    /// Consomme le corps d'une séquence commencée par ESC et rend ce qui suit.
    private static func consommer(_ suite: Substring) -> Substring {
        guard let premier = suite.first else { return suite }
        switch premier {
        case "[":
            return apresFinaleCSI(suite.dropFirst())
        case "]":
            return apresTerminateurOSC(suite.dropFirst())
        default:
            // ESC + intermédiaires (0x20-0x2F) + une finale. Couvre `ESC ( B`,
            // `ESC =`, `ESC >` et les autres séquences courtes.
            var reste = suite.drop { ("\u{20}"..."\u{2F}").contains($0) }
            if !reste.isEmpty { reste = reste.dropFirst() }
            return reste
        }
    }

    /// CSI : paramètres `0x30-0x3F`, intermédiaires `0x20-0x2F`, puis UNE finale
    /// entre `@` et `~`. La finale peut être n'importe laquelle des soixante-trois.
    private static func apresFinaleCSI(_ suite: Substring) -> Substring {
        var reste = suite.drop { ("\u{20}"..."\u{3F}").contains($0) }
        if let finale = reste.first, ("@"..."~").contains(finale) { reste = reste.dropFirst() }
        return reste
    }

    /// OSC : chaîne libre terminée par BEL ou par ST (`ESC \`).
    private static func apresTerminateurOSC(_ suite: Substring) -> Substring {
        var reste = suite
        while let courant = reste.first {
            reste = reste.dropFirst()
            if courant == cloche { return reste }
            if courant == echappement {
                if reste.first == "\\" { reste = reste.dropFirst() }
                return reste
            }
        }
        return reste
    }

    /// Un retour chariot réécrit la ligne : seul le dernier segment survit.
    /// C'est ce que fait un vrai terminal, et c'est ce qui rend lisibles les
    /// barres de progression que les TUI redessinent en boucle.
    private static func appliquerRetourChariot(_ ligne: String) -> String {
        guard ligne.contains("\r") else { return ligne }
        let segments = ligne.split(separator: "\r", omittingEmptySubsequences: false)
        return String(segments.last ?? "")
    }

    /// tmux rend systématiquement le panneau complet, donc des dizaines de
    /// lignes vides sous le prompt. Les garder ferait défiler l'écran dans le vide.
    private static func rognerFin(_ lignes: [String]) -> ArraySlice<String> {
        var fin = lignes.count
        while fin > 0, lignes[fin - 1].trimmingCharacters(in: .whitespaces).isEmpty { fin -= 1 }
        return lignes[0..<fin]
    }
}

extension Character {
    /// Contrôle C0 hors tabulation et retours : invisibles, ils polluent la
    /// mesure de largeur du texte et font sauter le rendu monospacé.
    fileprivate var isControleC0: Bool {
        guard let scalaire = unicodeScalars.first, unicodeScalars.count == 1 else { return false }
        return scalaire.value < 0x20 || scalaire.value == 0x7F
    }
}
