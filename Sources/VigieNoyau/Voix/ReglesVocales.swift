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

    /// Le premier message tapé après la sortie du mode porte l'annonce de sortie.
    public static func apresSortie(_ texte: String) -> String {
        "\(annonceSortie)\n\n\(texte)"
    }

    /// Couper la lecture : au moins deux vrais mots entendus, qui ne sont pas l'écho de la phrase lue.
    public static func couperLecture(entendu: String, phraseLue: String?) -> Bool {
        let mots = Self.mots(entendu)
        guard mots.count >= 2, mots.joined().count >= 5 else { return false }
        guard let phraseLue else { return true }
        let lus = Set(Self.mots(phraseLue))
        let etrangers = mots.filter { !lus.contains($0) }
        return etrangers.count >= 2
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
