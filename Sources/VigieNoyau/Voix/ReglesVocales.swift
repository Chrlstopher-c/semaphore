import Foundation

// Responsabilité : les règles du mode vocal qui ne dépendent d'aucun appareil — annonces faites à l'agent à l'entrée
// et à la sortie du mode, et décision de couper la lecture quand Chris parle (vrais mots, pas l'écho de la voix).

public enum ReglesVocales {
    public static let annonceEntree = "[Mode vocal activé : réponds à l'oral, phrases naturelles et courtes, "
        + "pas de listes ni de mise en forme ; les outils restent disponibles]"
    public static let annonceSortie = "[Mode vocal terminé]"
    /// Silence après la dernière parole entendue avant l'envoi automatique.
    public static let silenceFinDeTour: Double = 1.3

    /// Le message tel qu'il part : l'annonce d'entrée devant le premier message du mode.
    public static func message(_ texte: String, premier: Bool) -> String {
        premier ? "\(annonceEntree)\n\n\(texte)" : texte
    }

    /// Le message qui suit une coupure dit à l'agent où sa réponse a été interrompue, pour qu'il puisse la reprendre.
    public static func apresCoupure(_ texte: String, dit: String) -> String {
        let fin = dit.count > 300 ? "…" + String(dit.suffix(300)) : dit
        let entendu = fin.isEmpty ? "rien de ta réponse n'avait encore été lu" : "j'ai entendu jusqu'à : « \(fin) »"
        return "[Je t'ai coupé la parole pendant que ta réponse était lue à voix haute ; \(entendu). "
            + "Si je te demande de reprendre ou de répéter, redis la suite de cette réponse.]\n\n\(texte)"
    }

    /// Le premier message tapé après la sortie du mode porte l'annonce de sortie.
    public static func apresSortie(_ texte: String) -> String {
        "\(annonceSortie)\n\n\(texte)"
    }

    /// Couper la lecture dès UN vrai mot (3 lettres ou plus) qui n'est pas l'écho de la phrase lue (Chris, 22/11 :
    /// à deux mots la coupure ne tombait qu'à la fin de sa phrase).
    public static func couperLecture(entendu: String, phraseLue: String?) -> Bool {
        let mots = Self.mots(entendu).filter { $0.count >= 3 }
        guard !mots.isEmpty else { return false }
        guard let phraseLue else { return true }
        let lus = Set(Self.mots(phraseLue))
        return mots.contains { !lus.contains($0) }
    }

    public static func mots(_ texte: String) -> [String] {
        texte.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !["euh", "hum", "hm", "bah", "ben"].contains($0) }
    }
}

/// Ce que le fil dit au mode vocal : un delta de texte, un texte final, la fin du tour.
public enum ObservationVocale: Sendable, Equatable {
    case delta(session: String, bloc: String, texte: String)
    case final(session: String, texte: String)
    case tourFini(session: String)
}
