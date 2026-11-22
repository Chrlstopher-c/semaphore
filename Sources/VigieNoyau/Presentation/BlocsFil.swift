import Foundation

// Responsabilité : regrouper le fil structuré en blocs d'affichage — messages, réponses, suites d'actions, reste.

/// Une suite contiguë d'outils et de sous-agents, résumée en une ligne.
public struct GroupeActions: Sendable, Equatable, Identifiable {
    /// Identifiant du premier élément du groupe.
    public let id: Int
    public let elements: [ElementFil]
    public let resume: String
    /// Un outil sans résultat, ou un sous-agent sans fin, tourne encore.
    public let enCours: Bool
    public let echecs: Int
}

public enum BlocFil: Sendable, Equatable, Identifiable {
    case utilisateur(seq: Int, texte: String)
    case assistant(seq: Int, texte: String)
    case actions(GroupeActions)
    case autre(ElementFil)

    public var id: Int {
        switch self {
        case .utilisateur(let seq, _), .assistant(let seq, _): return seq
        case .actions(let groupe): return groupe.id
        case .autre(let element): return element.id
        }
    }
}

public enum BlocsFil {
    /// Les blocs du fil, dans l'ordre. Les listes de tâches successives se réduisent à la dernière, placée à la
    /// position de la première ; un outil ou un sous-agent consécutif rejoint le même groupe d'actions.
    public static func depuis(_ elements: [ElementFil]) -> [BlocFil] {
        var blocs: [BlocFil] = []
        var groupe: [ElementFil] = []
        for element in fusionnerTaches(elements) {
            if estAction(element) {
                groupe.append(element)
                continue
            }
            ajouterGroupe(groupe, dans: &blocs)
            groupe = []
            blocs.append(bloc(element))
        }
        ajouterGroupe(groupe, dans: &blocs)
        return blocs
    }

    static func fusionnerTaches(_ elements: [ElementFil]) -> [ElementFil] {
        let positions = elements.indices.filter { estTaches(elements[$0]) }
        guard positions.count > 1, let premier = positions.first, let dernier = positions.last else { return elements }
        return elements.enumerated().compactMap { i, element in
            if estTaches(element) { return i == premier ? elements[dernier] : nil }
            return element
        }
    }

    private static func estAction(_ element: ElementFil) -> Bool {
        switch element {
        case .outil, .sousAgent: return true
        case .simple: return false
        }
    }

    private static func estTaches(_ element: ElementFil) -> Bool {
        if case .simple(_, _, .taches) = element { return true }
        return false
    }

    private static func bloc(_ element: ElementFil) -> BlocFil {
        switch element {
        case .simple(let seq, _, .message(let texte, _, _)): return .utilisateur(seq: seq, texte: texte)
        case .simple(let seq, _, .texte(let texte, nil)): return .assistant(seq: seq, texte: texte)
        default: return .autre(element)
        }
    }

    private static func ajouterGroupe(_ groupe: [ElementFil], dans blocs: inout [BlocFil]) {
        guard let premier = groupe.first else { return }
        let noms = groupe.map(nomDe)
        let echecs = groupe.filter(echoue).count
        blocs.append(.actions(GroupeActions(id: premier.id, elements: groupe, resume: ResumeOutils.resume(noms: noms),
                                            enCours: groupe.contains(where: enCours), echecs: echecs)))
    }

    private static func nomDe(_ element: ElementFil) -> String {
        switch element {
        case .outil(let appel): return appel.nom
        case .sousAgent, .simple: return "Agent"
        }
    }

    private static func enCours(_ element: ElementFil) -> Bool {
        switch element {
        case .outil(let appel): return appel.resultat == nil
        case .sousAgent(let agent): return agent.fin == nil
        case .simple: return false
        }
    }

    private static func echoue(_ element: ElementFil) -> Bool {
        switch element {
        case .outil(let appel): return appel.resultat?.erreur == true
        case .sousAgent(let agent): return agent.fin?.erreur == true
        case .simple: return false
        }
    }
}
