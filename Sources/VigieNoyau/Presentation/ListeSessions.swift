import Foundation

// Responsabilité : la liste des sessions telle qu'on la montre — icône de statut, sous-titre, appareil d'origine.

public enum IconeStatut: String, Sendable, Equatable {
    case travail, question, erreur, repos
}

public enum IconeAppareil: String, Sendable, Equatable {
    case portable, tour, pi, nuage, autre
}

public struct LigneSession: Identifiable, Sendable, Equatable {
    public let id: String
    public let titre: String
    public let sousTitre: String
    public let statut: IconeStatut
    public let nonLue: Bool
    public let appareil: IconeAppareil
    public let appareilEnLigne: Bool
    /// Le relais n'a pas de vrai titre : la vue demande le début du fil pour en faire un.
    public let titreDeRepli: Bool
}

public enum ListeSessions {
    /// Les sessions non archivées (ou seulement les archivées), les plus récentes d'abord (`majLe`).
    public static func lignes(_ sessions: [Session], machines: [Machine], maintenant: Date,
                              fuseau: TimeZone = .current, archivees: Bool = false,
                              premiersMessages: [String: String] = [:]) -> [LigneSession] {
        let vues = sessions.filter { ($0.archivee == true) == archivees }
            .map { (session: $0, majLe: DateRelative.date($0.majLe) ?? .distantPast) }
            .sorted { $0.majLe > $1.majLe }
        return vues.map {
            ligne($0.session, machines: machines, maintenant: maintenant, fuseau: fuseau,
                  premier: premiersMessages[$0.session.id])
        }
    }

    static func ligne(_ session: Session, machines: [Machine], maintenant: Date, fuseau: TimeZone,
                      premier: String? = nil) -> LigneSession {
        let machine = machines.first { $0.id == session.machine }
        let icone = icone(session)
        return LigneSession(
            id: session.id,
            titre: TitreSession.affiche(session, premierMessage: premier),
            sousTitre: sousTitre(session, icone: icone, maintenant: maintenant, fuseau: fuseau),
            statut: icone,
            nonLue: session.nonLue ?? false,
            appareil: appareil(session, machine: machine),
            appareilEnLigne: machine?.enLigne ?? false,
            titreDeRepli: TitreSession.estDeRepli(session) && premier == nil
        )
    }

    static func icone(_ session: Session) -> IconeStatut {
        if session.statut == .question || session.dialogue != nil { return .question }
        if session.statut == .erreur { return .erreur }
        if session.statut.enActivite { return .travail }
        return .repos
    }

    static func sousTitre(_ session: Session, icone: IconeStatut, maintenant: Date, fuseau: TimeZone) -> String {
        let relatif = DateRelative.texte(iso: session.majLe, maintenant: maintenant, fuseau: fuseau)
        switch icone {
        case .question: return "Attend ta réponse · \(relatif)"
        case .erreur: return "Arrêtée · erreur"
        case .travail: return relatif
        case .repos: return reposSousTitre(session.statut, relatif: relatif)
        }
    }

    private static func reposSousTitre(_ statut: StatutSession, relatif: String) -> String {
        switch statut {
        case .attente: return "En attente · \(relatif)"
        case .terminee: return "Terminée · \(relatif)"
        default: return relatif
        }
    }

    /// `claude_ai` : une session Remote Control, dans le nuage. Sinon, l'appareil se lit dans le nom de la machine.
    static func appareil(_ session: Session, machine: Machine?) -> IconeAppareil {
        if session.moteur == "claude_ai" { return .nuage }
        let identifiant = session.machine.lowercased()
        let description = (machine?.description ?? "").lowercased()
        let mots = Set(description.split { !$0.isLetter }.map(String.init))
        if identifiant.contains("portable") || description.contains("portable") { return .portable }
        if identifiant == "pi" || mots.contains("pi") { return .pi }
        if identifiant.contains("tour") || description.contains("tour") { return .tour }
        return .autre
    }
}
