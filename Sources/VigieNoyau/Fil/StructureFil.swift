import Foundation

// Structure le fil brut d'une session : chaque résultat rejoint son outil, chaque sous-agent regroupe ce qu'il a fait.
// Même règle que `bureau/src/sessions/fil/structure.ts` de ccremote — les deux clients montrent le même fil.

public struct AppelOutil: Sendable, Equatable, Identifiable {
    public let id: Int
    public let outilId: String
    public let nom: String
    public let resume: String
    public let detail: String
    public var resultat: Resultat?

    public struct Resultat: Sendable, Equatable {
        public let extrait: String
        public let erreur: Bool
    }
}

public enum ElementInterne: Sendable, Equatable, Identifiable {
    case outil(AppelOutil)
    case texte(seq: Int, texte: String)

    public var id: Int {
        switch self {
        case .outil(let o): return o.id
        case .texte(let seq, _): return seq
        }
    }
}

public struct SousAgent: Sendable, Equatable, Identifiable {
    public let id: Int
    public let outilId: String
    public let description: String
    public let modele: String
    public let genre: String
    public var interieur: [ElementInterne] = []
    public var fin: AppelOutil.Resultat?

    /// Le dernier texte du sous-agent est son rapport.
    public var rapport: String? {
        for element in interieur.reversed() { if case .texte(_, let t) = element { return t } }
        return nil
    }

    public var nombreOutils: Int {
        interieur.filter { if case .outil = $0 { return true } else { return false } }.count
    }
}

public enum ElementFil: Sendable, Equatable, Identifiable {
    case outil(AppelOutil)
    case sousAgent(SousAgent)
    case simple(seq: Int, ts: String, evt: Evenement)

    public var id: Int {
        switch self {
        case .outil(let o): return o.id
        case .sousAgent(let a): return a.id
        case .simple(let seq, _, _): return seq
        }
    }
}

public enum StructureFil {
    /// Un sous-agent en arrière-plan répond d'abord « lancé » : ce n'est pas sa fin, qui arrive plus tard.
    static let accuseLancement = "Async agent launched"

    public static func structurer(_ evts: [EvenementDate]) -> [ElementFil] {
        var construction = Construction()
        for e in evts { construction.ajouter(e) }
        return construction.fil.map { construction.resoudre($0) }
    }
}

/// Accumule le fil ; les outils et sous-agents sont gardés par référence d'index pour recevoir leur résultat plus tard.
private struct Construction {
    var fil: [Place] = []
    var outils: [AppelOutil] = []
    var agents: [SousAgent] = []
    var indexOutil: [String: Int] = [:]
    var indexAgent: [String: Int] = [:]

    enum Place { case outil(Int), agent(Int), simple(Int, String, Evenement) }

    mutating func ajouter(_ e: EvenementDate) {
        switch e.evt {
        case .tourFini, .inconnu: return
        case .resultatOutil(let outilId, let extrait, let erreur, _): recevoirResultat(outilId, .init(extrait: extrait, erreur: erreur))
        case .outil(let id, let nom, let resume, let detail, let agent): ajouterOutil(e.seq, id, nom, resume, detail, agent)
        case .sousAgent(let id, let description, let modele, let genre):
            indexAgent[id] = agents.count
            agents.append(SousAgent(id: e.seq, outilId: id, description: description, modele: modele, genre: genre))
            fil.append(.agent(agents.count - 1))
        case .texte(let t, let agent?), .reflexion(let t, let agent?):
            if let i = indexAgent[agent] { agents[i].interieur.append(.texte(seq: e.seq, texte: t)) }
        default: fil.append(.simple(e.seq, e.ts, e.evt))
        }
    }

    mutating func ajouterOutil(_ seq: Int, _ id: String, _ nom: String, _ resume: String, _ detail: String, _ agent: String?) {
        let appel = AppelOutil(id: seq, outilId: id, nom: nom, resume: resume, detail: detail)
        if let agent, let i = indexAgent[agent] {
            indexOutil[id] = -(i + 1) // négatif : l'outil vit dans le sous-agent i
            agents[i].interieur.append(.outil(appel))
            return
        }
        indexOutil[id] = outils.count
        outils.append(appel)
        fil.append(.outil(outils.count - 1))
    }

    mutating func recevoirResultat(_ outilId: String, _ r: AppelOutil.Resultat) {
        if let i = indexAgent[outilId] {
            if !r.extrait.hasPrefix(StructureFil.accuseLancement) { agents[i].fin = r }
            return
        }
        guard let place = indexOutil[outilId] else { return }
        if place >= 0 { outils[place].resultat = r; return }
        let a = -place - 1
        for (k, element) in agents[a].interieur.enumerated() {
            if case .outil(var o) = element, o.outilId == outilId { o.resultat = r; agents[a].interieur[k] = .outil(o) }
        }
    }

    func resoudre(_ p: Place) -> ElementFil {
        switch p {
        case .outil(let i): return .outil(outils[i])
        case .agent(let i): return .sousAgent(agents[i])
        case .simple(let seq, let ts, let evt): return .simple(seq: seq, ts: ts, evt: evt)
        }
    }
}
