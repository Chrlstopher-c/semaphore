import Foundation

/// Les lignes `system` du fil, du jargon vers du français.
///
/// `☠` Le fil porte les identifiants du registre tels quels — « planifiee →
/// en_cours », « running », « en_cours → terminee ». Ce sont des valeurs de
/// colonne SQL, montrées à quelqu'un qui ne lit jamais de code.
///
/// `☠` On traduit ICI, jamais côté serveur : `texteTransition` est aussi ce que
/// lit l'orchestrateur par `outils-inspection.ts`, qui a besoin des identifiants
/// exacts. Deux publics, deux vocabulaires.
public enum TransitionEquipe {

    /// Une ligne de transition décomposée : `[origine] avant → après — motif`.
    public struct Analyse: Sendable, Hashable {
        public let origine: String
        public let passage: String
        public let avant: String
        public let apres: String
        public let motif: String
    }

    /// État d'arrivée → ce qui vient d'arriver, du point de vue de l'opérateur.
    static let etatsLisibles: [String: String] = [
        "planifiee": "équipe planifiée",
        "en_cours": "équipe démarrée",
        "en_pause": "équipe mise en pause",
        "attente_machine": "en attente de la machine",
        "echec_definitif": "équipe en échec",
        "terminee": "équipe terminée",
        "annulee": "équipe annulée",
        "idle": "le lead a rendu la main",
        "running": "le lead travaille",
        "requires_action": "le lead attend une autorisation",
    ]

    /// Passages dont l'état d'arrivée seul dirait faux : arriver sur `en_cours`
    /// depuis `en_pause` est une reprise, pas un démarrage.
    static let passagesLisibles: [String: String] = [
        "en_pause>en_cours": "équipe reprise",
        "attente_machine>en_cours": "machine retrouvée, équipe repartie",
    ]

    /// `☠` Le motif est cherché sur ` — ` et pas sur `—` seul : un motif libre
    /// peut contenir un tiret cadratin collé, la séquence espacée est celle du
    /// format.
    public static func analyser(_ texte: String) -> Analyse {
        let brut = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        let (origine, reste) = detacherOrigine(brut)
        let coupe = reste.range(of: " — ")
        let passage = coupe.map { String(reste[reste.startIndex..<$0.lowerBound]) } ?? reste
        let motif = coupe
            .map { String(reste[$0.upperBound...]).trimmingCharacters(in: .whitespaces) } ?? ""
        let bornes = passage.components(separatedBy: " → ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return Analyse(
            origine: origine,
            passage: passage,
            avant: bornes.count > 1 ? bornes[0] : "",
            apres: bornes.last ?? passage,
            motif: motif
        )
    }

    private static func detacherOrigine(_ brut: String) -> (String, String) {
        guard brut.hasPrefix("["), let fin = brut.firstIndex(of: "]") else { return ("", brut) }
        let origine = String(brut[brut.index(after: brut.startIndex)..<fin])
        let reste = String(brut[brut.index(after: fin)...]).trimmingCharacters(in: .whitespaces)
        return (origine, reste)
    }

    /// `☠` Repli sur le PASSAGE brut si l'état est inconnu — un vocabulaire qui
    /// s'enrichit côté serveur ne doit jamais faire DISPARAÎTRE une ligne du
    /// fil. Sur le passage, pas sur le texte entier : celui-ci porte déjà le
    /// motif, qu'on recolle juste après.
    public static func phrase(_ analyse: Analyse) -> String {
        let libelle = passagesLisibles["\(analyse.avant)>\(analyse.apres)"]
            ?? etatsLisibles[analyse.apres]
            ?? analyse.passage
        let phrase = analyse.motif.isEmpty ? libelle : "\(libelle) — \(analyse.motif)"
        return LibelleValise.majuscule(phrase)
    }

    /// La phrase d'une RAFALE de transitions consécutives.
    ///
    /// `☠` « running → idle » puis « en_cours → terminee » à une seconde d'écart
    /// disent la même chose : le lead a fini. On garde la dernière transition du
    /// Pi quand il y en a une — c'est lui l'autorité sur le cycle de vie de
    /// l'équipe, le SDK ne fait qu'osciller à chaque tour.
    public static func lisible(_ lignes: [FeedEventApi]) -> String {
        let analyses = lignes.map { analyser($0.text) }
        guard !analyses.isEmpty else { return "" }
        let duPi = analyses.filter { $0.origine == "harness" }
        return phrase(duPi.last ?? analyses[analyses.count - 1])
    }
}
