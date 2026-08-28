import Foundation

/// Lecture des appels d'outil du fil d'une équipe.
///
/// Le fil brut d'une mission réelle, c'est ~90 lignes dont l'écrasante majorité
/// sont des appels d'outils. Les rendre un par un noie la seule chose qu'on
/// vient lire — ce que le lead DIT. D'où le regroupement en valises, et d'où ce
/// module : composer la ligne qui résume une rafale.
public enum LibelleOutil {

    /// Décompose le résumé d'entrée produit par le PC
    /// (`collecteur-telemetrie.ts` : `champ=valeur · champ=valeur`).
    ///
    /// `☠` Découpe sur le PREMIER `=` seulement : une commande shell en contient.
    public static func champs(_ texte: String) -> [String: String] {
        var trouves: [String: String] = [:]
        for morceau in texte.components(separatedBy: " · ") {
            guard let coupe = morceau.firstIndex(of: "="), coupe > morceau.startIndex else { continue }
            let cle = String(morceau[morceau.startIndex..<coupe])
            trouves[cle] = String(morceau[morceau.index(after: coupe)...])
        }
        return trouves
    }

    /// Le chemin visé par un appel, quel que soit le nom du champ.
    public static func chemin(_ champs: [String: String]) -> String? {
        champs["file_path"] ?? champs["path"] ?? champs["notebook_path"]
    }

    /// Ce qu'on montre d'un appel sur une seule ligne.
    public static func resume(_ evenement: FeedEventApi) -> String {
        let c = champs(evenement.text)
        if let description = c["description"], !description.isEmpty { return description }
        if let chemin = chemin(c), !chemin.isEmpty { return dernierSegment(chemin) }
        for cle in ["pattern", "query", "url", "command"] {
            if let valeur = c[cle], !valeur.isEmpty { return valeur }
        }
        if let outil = evenement.tool, !outil.isEmpty { return outil }
        return "action"
    }

    /// Un appel `Task` : le moment où le lead confie du travail à un sous-agent.
    /// La seule ligne du fil qui ouvre sur le travail d'un AUTRE agent.
    public static func estDelegation(_ evenement: FeedEventApi) -> Bool {
        evenement.type == .activite && evenement.nature == .outil && evenement.tool == "Task"
    }

    /// Le nom parlant d'une délégation.
    ///
    /// `☠` C'est la SEULE clé de rapprochement entre un appel `Task` du fil et
    /// un sous-agent du registre : `subagent_type` n'est pas relevé par le PC et
    /// l'`agentId` du CLI n'existe pas encore à l'instant de l'appel. Côté API,
    /// `SubagentApi.name` vaut `description ?? type ?? agentId` — l'égalité ne
    /// tient donc QUE si la description a été relevée. Sinon, on ne rapproche rien.
    public static func nomDelegation(_ evenement: FeedEventApi) -> String? {
        let nom = (champs(evenement.text)["description"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return nom.isEmpty ? nil : nom
    }

    public static func dernierSegment(_ chemin: String) -> String {
        chemin.split(separator: "/").last.map(String.init) ?? chemin
    }
}
