import Foundation

// Responsabilité : les libellés des résumés d'outils au format de Desktop (« Exécuté 2 commandes »).
// Portés de `app/ui/src/fil/resume-outils.ts` et `libelles-outils.ts` (Lanterne). Entrée : les noms seuls.

public enum ResumeOutils {
    static let maxParties = 3

    /// Résumé d'un groupe d'appels : « Exécuté 2 commandes, lu 1 fichier, et 2 autres actions ».
    public static func resume(noms: [String]) -> String {
        var ordre: [String] = []
        var comptes: [String: (partie: Partie, nombre: Int)] = [:]
        for nom in noms {
            let partie = Partie.de(nom)
            if comptes[partie.cle] == nil { ordre.append(partie.cle) }
            comptes[partie.cle] = (partie, (comptes[partie.cle]?.nombre ?? 0) + 1)
        }
        let parties = ordre.compactMap { cle in comptes[cle].map { $0.partie.libelle($0.nombre) } }
        var texte = parties.prefix(maxParties).joined(separator: ", ")
        let reste = parties.count - min(parties.count, maxParties)
        if reste > 0 { texte += ", et \(reste) \(reste > 1 ? "autres actions" : "autre action")" }
        return majuscule(texte)
    }

    /// Ce que fait un appel en cours : sa description (Bash), sinon l'intitulé court de son action.
    public static func intituleEnCours(nom: String, entree: String) -> String {
        if let description = descriptionDe(entree) { return description }
        if let intitule = intitules[nom] { return intitule }
        return activite(nom: nom, entree: entree)
    }

    /// Serveur MCP lisible : « plan-progress » devient « Plan progress », « claude_ai_Gmail » « Gmail ».
    public static func serveurLisible(_ service: String) -> String {
        let sansPrefixe = service.replacing(/(?i)^claude[_ .-]ai[_ .-]+/, with: "")
        let texte = sansPrefixe.replacing(/[-_]+/, with: " ").trimmingCharacters(in: .whitespaces)
        return majuscule(texte.isEmpty ? service : texte)
    }

    /// Nom d'un appel MCP : « Linkedin: note », ou le serveur seul quand l'outil porte son nom.
    public static func nomMcpLisible(service: String, outil: String) -> String {
        let reste = outilLisible(service: service, outil: outil)
        return reste.isEmpty ? serveurLisible(service) : "\(serveurLisible(service)): \(reste)"
    }

    /// Découpe `mcp__<service>__<outil>` ; un outil intégré n'a pas de service.
    public static func analyser(_ nom: String) -> (service: String?, outil: String) {
        let morceaux = nom.components(separatedBy: "__")
        if morceaux.count >= 3 && morceaux[0] == "mcp" {
            return (morceaux[1], morceaux.dropFirst(2).joined(separator: "__").replacingOccurrences(of: "_", with: " "))
        }
        return (nil, nom)
    }

    static func estMemoire(service: String?, outil: String) -> Bool {
        guard let service else { return false }
        let serviceBas = service.lowercased()
        let memoireDeService = ["semantic-memory", "semantic_memory", "hippocampe"].contains(serviceBas)
        return memoireDeService || outil.hasPrefix("hippo ") || outil.hasPrefix("memory ")
    }

    private static func majuscule(_ texte: String) -> String {
        texte.prefix(1).uppercased() + texte.dropFirst()
    }

    private static func descriptionDe(_ entree: String) -> String? {
        let brut = entree.trimmingCharacters(in: .whitespacesAndNewlines)
        guard brut.hasPrefix("{"), let donnees = brut.data(using: .utf8),
              let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any],
              let description = objet["description"] as? String, !description.isEmpty else { return nil }
        return description
    }

    private static func activite(nom: String, entree: String) -> String {
        if nom == "Agent" || nom == "Task" { return "Exécution de l'agent" }
        if nom == "SendMessage" { return "Envoi d'un message à l'agent" }
        if nom == "AskUserQuestion" { return "Attend votre réponse" }
        if nom == "ToolSearch" { return "Chargement des outils" }
        let (service, outil) = analyser(nom)
        if estMemoire(service: service, outil: outil) { return libelleMemoire(outil) }
        if let service { return "Utilisation de \(nomMcpLisible(service: service, outil: outil))" }
        return Famille.de(nom).enCours
    }

    private static func libelleMemoire(_ geste: String) -> String {
        switch geste {
        case "memory store": return "Retient"
        case "memory update": return "Corrige un souvenir"
        case "memory delete": return "Oublie un souvenir"
        case "hippo fiche": return "Relit la fiche"
        case "hippo cherche", "memory search": return "Cherche dans la mémoire"
        case "hippo recap": return "Relit les derniers jours"
        case "hippo index": return "Relit l'index de la mémoire"
        default: return "Consulte la mémoire"
        }
    }

    private static func outilLisible(service: String, outil: String) -> String {
        let cle = compact(serveurSansPrefixe(service))
        let mots = outil.split(whereSeparator: \.isWhitespace).map(String.init)
        for k in mots.indices where compact(mots.prefix(k + 1).joined()) == cle {
            return mots.dropFirst(k + 1).joined(separator: " ")
        }
        return outil.trimmingCharacters(in: .whitespaces)
    }

    private static func serveurSansPrefixe(_ service: String) -> String {
        service.replacing(/(?i)^claude[_ .-]ai[_ .-]+/, with: "")
    }

    private static func compact(_ texte: String) -> String {
        texte.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static let intitules: [String: String] = [
        "Bash": "Exécution", "Read": "Lecture", "Edit": "Modification", "MultiEdit": "Modification",
        "Write": "Création", "NotebookEdit": "Modification", "Grep": "Recherche", "Glob": "Recherche",
        "WebFetch": "Lecture du web", "WebSearch": "Recherche sur le web",
    ]
}

/// Une partie du résumé : ce qu'on compte (outils intégrés, serveur MCP, mémoire, chargement, message).
enum Partie: Equatable {
    case chargement, message, memoireEcrit, memoireLue, serveur(String), famille(Famille)

    static func de(_ nom: String) -> Partie {
        if nom == "ToolSearch" { return .chargement }
        if nom == "SendMessage" { return .message }
        let (service, outil) = ResumeOutils.analyser(nom)
        if ResumeOutils.estMemoire(service: service, outil: outil) {
            let ecrit = outil.hasPrefix("memory ") && (outil.hasSuffix(" store") || outil.hasSuffix(" update"))
            return ecrit ? .memoireEcrit : .memoireLue
        }
        if let service { return .serveur(service) }
        return .famille(Famille.de(nom))
    }

    var cle: String {
        switch self {
        case .chargement: return "chargement"
        case .message: return "message"
        case .memoireEcrit: return "memoire:ecrit"
        case .memoireLue: return "memoire:lu"
        case .serveur(let service): return "mcp:\(service)"
        case .famille(let f): return "\(f.verbe) \(f.singulier)\u{0}\(f.pluriel)"
        }
    }

    func libelle(_ n: Int) -> String {
        switch self {
        case .chargement: return "Outils chargés"
        case .message: return "Message envoyé à l'agent"
        case .memoireEcrit: return n > 1 ? "a retenu \(n) souvenirs" : "a retenu 1 souvenir"
        case .memoireLue: return n > 1 ? "a consulté la mémoire \(n) fois" : "a consulté la mémoire"
        case .serveur(let service):
            let nom = ResumeOutils.serveurLisible(service)
            return n > 1 ? "Utilisé \(nom) \(n) fois" : "Utilisé \(nom)"
        case .famille(let f): return "\(f.verbe) \(n) \(n > 1 ? f.pluriel : f.singulier)"
        }
    }
}

/// Famille d'un outil intégré : verbe passé, nom au singulier et au pluriel, forme en cours.
struct Famille: Equatable, Sendable {
    let verbe: String
    let singulier: String
    let pluriel: String
    let enCours: String

    static func de(_ nom: String) -> Famille {
        table[nom] ?? Famille(verbe: "utilisé", singulier: nom, pluriel: nom, enCours: "En train d'utiliser \(nom)")
    }

    private static let table: [String: Famille] = [
        "Bash": Famille(verbe: "exécuté", singulier: "commande", pluriel: "commandes",
                        enCours: "En train d'exécuter une commande"),
        "Read": Famille(verbe: "lu", singulier: "fichier", pluriel: "fichiers", enCours: "En train de lire un fichier"),
        "Edit": Famille(verbe: "modifié", singulier: "fichier", pluriel: "fichiers",
                        enCours: "En train de modifier un fichier"),
        "MultiEdit": Famille(verbe: "modifié", singulier: "fichier", pluriel: "fichiers",
                             enCours: "En train de modifier un fichier"),
        "Write": Famille(verbe: "créé", singulier: "fichier", pluriel: "fichiers",
                        enCours: "En train de créer un fichier"),
        "Grep": Famille(verbe: "recherché", singulier: "motif", pluriel: "motifs", enCours: "En train de rechercher"),
        "Glob": Famille(verbe: "listé", singulier: "motif", pluriel: "motifs",
                        enCours: "En train de lister des fichiers"),
        "Agent": Famille(verbe: "exécuté", singulier: "agent", pluriel: "agents", enCours: "Exécution de l'agent"),
        "Task": Famille(verbe: "exécuté", singulier: "agent", pluriel: "agents", enCours: "Exécution de l'agent"),
        "AskUserQuestion": Famille(verbe: "posé", singulier: "question", pluriel: "questions",
                                   enCours: "Attend votre réponse"),
    ]
}
