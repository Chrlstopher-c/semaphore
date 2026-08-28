import Foundation

/// Le libellé d'une rafale d'outils : « Exécuté 7 commandes, lu 2 fichiers ».
///
/// Groupé par VERBE et non par outil — « exécuté 3 commandes, exécuté 4
/// commandes » n'apprend rien de plus et rallonge la ligne.
public enum LibelleValise {

    /// Verbe et unités d'un outil connu.
    struct Verbe: Sendable {
        let mot: String
        let un: String
        let plusieurs: String
    }

    static let connus: [String: Verbe] = [
        "Bash": Verbe(mot: "exécuté", un: "commande", plusieurs: "commandes"),
        "BashOutput": Verbe(mot: "exécuté", un: "commande", plusieurs: "commandes"),
        "Read": Verbe(mot: "lu", un: "fichier", plusieurs: "fichiers"),
        "NotebookRead": Verbe(mot: "lu", un: "fichier", plusieurs: "fichiers"),
        "Write": Verbe(mot: "écrit", un: "fichier", plusieurs: "fichiers"),
        "Edit": Verbe(mot: "modifié", un: "fichier", plusieurs: "fichiers"),
        "NotebookEdit": Verbe(mot: "modifié", un: "fichier", plusieurs: "fichiers"),
        "Grep": Verbe(mot: "cherché", un: "motif", plusieurs: "motifs"),
        "Glob": Verbe(mot: "cherché", un: "motif", plusieurs: "motifs"),
        "WebFetch": Verbe(mot: "consulté", un: "page", plusieurs: "pages"),
        "WebSearch": Verbe(mot: "cherché sur le web", un: "", plusieurs: ""),
        "Task": Verbe(mot: "délégué à", un: "sous-agent", plusieurs: "sous-agents"),
        "TodoWrite": Verbe(mot: "mis à jour le plan", un: "", plusieurs: ""),
        "ToolSearch": Verbe(mot: "cherché un outil", un: "", plusieurs: ""),
        "Skill": Verbe(mot: "chargé", un: "compétence", plusieurs: "compétences"),
    ]

    /// Outils dont l'argument est un chemin : nommés plutôt que comptés quand
    /// ils sont seuls.
    static let outilsDeFichier: Set<String> = [
        "Read", "NotebookRead", "Write", "Edit", "NotebookEdit",
    ]

    static func verbe(_ outil: String?) -> Verbe {
        let nom = outil ?? ""
        if let connu = connus[nom] { return connu }
        guard nom.hasPrefix("mcp__") else {
            return Verbe(mot: "utilisé", un: "outil", plusieurs: "outils")
        }
        let court = nomCourtMcp(nom)
        return Verbe(mot: "appelé", un: court, plusieurs: court)
    }

    /// `mcp__serveur__outil` → `outil`. Le préfixe de serveur n'apprend rien à
    /// qui lit un fil.
    static func nomCourtMcp(_ outil: String) -> String {
        // Cherché en AVANT depuis la fin du préfixe, jamais en arrière : un nom
        // d'outil peut lui-même porter un `__`, et remonter depuis la fin en
        // amputerait la moitié.
        let reste = outil.dropFirst("mcp__".count)
        guard let separateur = reste.range(of: "__") else { return outil }
        let court = String(reste[separateur.upperBound...])
        return court.isEmpty ? outil : court
    }

    /// Accumulateur d'un groupe : le verbe, son compte, et les noms retenus.
    private struct Groupe {
        let verbe: Verbe
        var compte = 0
        var exemples: [String] = []
    }

    public static func pour(_ appels: [FeedEventApi]) -> String {
        var ordre: [String] = []
        var groupes: [String: Groupe] = [:]
        for appel in appels {
            let verbe = verbe(appel.tool)
            // `☠` La clé porte le verbe ET l'unité : deux outils MCP distincts
            // partagent le verbe « appelé » et se fondraient en un décompte faux.
            let cle = "\(verbe.mot)|\(verbe.un)"
            if groupes[cle] == nil {
                ordre.append(cle)
                groupes[cle] = Groupe(verbe: verbe)
            }
            groupes[cle]?.compte += 1
            if let exemple = exemple(appel) { groupes[cle]?.exemples.append(exemple) }
        }
        let phrase = ordre.compactMap { groupes[$0].map(morceau) }.joined(separator: ", ")
        return majuscule(phrase)
    }

    private static func exemple(_ appel: FeedEventApi) -> String? {
        if let outil = appel.tool, outilsDeFichier.contains(outil) {
            return LibelleOutil.chemin(LibelleOutil.champs(appel.text)).map(LibelleOutil.dernierSegment)
        }
        // Une délégation seule est NOMMÉE comme un fichier seul : « délégué à
        // Refonte du header » dit à qui, « délégué à 1 sous-agent » ne dit rien.
        if LibelleOutil.estDelegation(appel) { return LibelleOutil.nomDelegation(appel) }
        return nil
    }

    private static func morceau(_ groupe: Groupe) -> String {
        let verbe = groupe.verbe
        // Un fichier seul est NOMMÉ, pas compté : « lu TODO.md » dit ce qui a
        // été lu, « lu 1 fichier » ne dit rien de plus qu'un compteur à un.
        if groupe.compte == 1, groupe.exemples.count == 1 {
            return "\(verbe.mot) \(groupe.exemples[0])"
        }
        if verbe.un.isEmpty {
            return groupe.compte == 1 ? verbe.mot : "\(verbe.mot) ×\(groupe.compte)"
        }
        if verbe.un == verbe.plusieurs {
            return groupe.compte == 1
                ? "\(verbe.mot) \(verbe.un)"
                : "\(verbe.mot) \(verbe.un) ×\(groupe.compte)"
        }
        let unite = groupe.compte == 1 ? verbe.un : verbe.plusieurs
        return "\(verbe.mot) \(groupe.compte) \(unite)"
    }

    static func majuscule(_ phrase: String) -> String {
        guard let premiere = phrase.first else { return phrase }
        return premiere.uppercased() + phrase.dropFirst()
    }
}
