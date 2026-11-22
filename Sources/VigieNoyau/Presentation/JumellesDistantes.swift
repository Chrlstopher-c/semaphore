import Foundation

// Responsabilité : rapprochement des sessions de poste et de leurs jumelles Remote Control (claude.ai). Port exact de
// `app/ui/src/sessions/jumelles-distantes.ts` (Lanterne) : conversation d'abord, titre et dossier en repli. Pur.

/// Une session de poste et sa jumelle claude.ai ne se listent qu'une fois : par le poste, le fil complet.
public enum JumellesDistantes {
    private struct Index {
        var parConversation: [String: Session] = [:]
        var parTitre: [String: Session] = [:]
    }

    /// Pour chaque session de poste qui a une jumelle Remote Control : id du poste → id de la session claude.ai.
    public static func jumelles(_ sessions: [Session]) -> [String: String] {
        var jumelles: [String: String] = [:]
        for (poste, distante) in paires(sessions) where jumelles[poste] == nil {
            jumelles[poste] = distante
        }
        return jumelles
    }

    /// Les sessions sans les jumelles Remote Control qui doublonnent une session du parc.
    public static func sansDoublons(_ sessions: [Session]) -> [Session] {
        let doublons = Set(jumelles(sessions).values)
        return doublons.isEmpty ? sessions : sessions.filter { !doublons.contains($0.id) }
    }

    /// Session dont le fil, le panneau et les sous-agents se lisent : la fiche de poste d'une jumelle, sinon
    /// la sienne.
    public static func lecture(_ id: String, _ sessions: [Session]) -> String {
        guard let session = sessions.first(where: { $0.id == id }), estDistante(session) else { return id }
        return paires(sessions).first(where: { $0.1 == session.id })?.0 ?? id
    }

    /// Session à qui partent les écritures (envoi, interruption, réglages, réponses) : la jumelle Remote Control.
    public static func ecriture(_ id: String, _ sessions: [Session]) -> String {
        jumelles(sessions)[id] ?? id
    }

    /// Les couples (poste, distante) dans l'ordre des sessions : le premier poste gagne si deux se disputent
    /// une jumelle.
    private static func paires(_ sessions: [Session]) -> [(String, String)] {
        let index = indexer(sessions)
        guard !index.parConversation.isEmpty || !index.parTitre.isEmpty else { return [] }
        return sessions.compactMap { session -> (String, String)? in
            guard !estDistante(session), let jumelle = jumelleDe(session, index) else { return nil }
            return (session.id, jumelle.id)
        }
    }

    /// Index des sessions claude.ai : par conversation d'abord, par titre et dossier pour celles qui n'en ont pas.
    private static func indexer(_ sessions: [Session]) -> Index {
        var index = Index()
        for session in sessions where estDistante(session) && session.archivee != true {
            if let conversation = session.distant?.conversation {
                index.parConversation[conversation] = session
            } else if let cle = cleDistante(session) {
                index.parTitre[cle] = session
            }
        }
        return index
    }

    private static func jumelleDe(_ session: Session, _ index: Index) -> Session? {
        if let conversation = session.claudeSessionId, let jumelle = index.parConversation[conversation] {
            return jumelle
        }
        return index.parTitre[cle(session.titre, session.cwd)]
    }

    /// Clé titre + dossier réel d'une session claude.ai ; nil si elle n'a pas de quoi se reconnaître dans le parc.
    private static func cleDistante(_ session: Session) -> String? {
        guard let dossier = session.distant?.cwdReel ?? session.distant?.cwd, !dossier.isEmpty else { return nil }
        guard !titreNu(session.titre).isEmpty else { return nil }
        return cle(session.titre, dossier)
    }

    private static func cle(_ titre: String, _ dossier: String) -> String {
        "\(titreNu(titre))\u{0}\(sansBarresFinales(dossier))"
    }

    private static func titreNu(_ titre: String) -> String {
        titre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sansBarresFinales(_ dossier: String) -> String {
        var nu = Substring(dossier)
        while nu.hasSuffix("/") { nu = nu.dropLast() }
        return String(nu)
    }

    private static func estDistante(_ session: Session) -> Bool {
        session.moteur == "claude_ai"
    }
}
