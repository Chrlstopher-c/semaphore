import Foundation

// Responsabilité : les réglages d'un invité (modèles, efforts, parts, machines, accès) — types, défaut, lecture
// et écriture JSON. Mêmes bornes que `commun/invites.ts` : une valeur hors bornes est refusée, jamais corrigée.

public struct AccesInvite: Sendable, Equatable {
    public var remoteControl: Bool
    public var terminaux: Bool
    public var sessionsAutres: Bool
    public var modules: Bool
    public var fichiersHors: Bool

    public init(remoteControl: Bool, terminaux: Bool, sessionsAutres: Bool, modules: Bool, fichiersHors: Bool) {
        self.remoteControl = remoteControl
        self.terminaux = terminaux
        self.sessionsAutres = sessionsAutres
        self.modules = modules
        self.fichiersHors = fichiersHors
    }

    public static let aucun = AccesInvite(
        remoteControl: false, terminaux: false, sessionsAutres: false, modules: false, fichiersHors: false)

    var valeurJSON: ValeurJSON {
        .objet([
            "remoteControl": .booleen(remoteControl), "terminaux": .booleen(terminaux),
            "sessionsAutres": .booleen(sessionsAutres), "modules": .booleen(modules),
            "fichiersHors": .booleen(fichiersHors),
        ])
    }
}

public struct ReglagesInvite: Sendable, Equatable {
    /// Famille (haiku|sonnet|opus|fable) → efforts permis ; famille absente = modèle interdit.
    public var modeles: [String: [String]]
    public var part5h: Int
    public var partSemaine: Int?
    public var simultanees: Int
    public var machines: [String]
    public var surSaMachine: Bool
    public var prompt: String
    public var acces: AccesInvite
    public var telemetrie: Bool

    public static let familles = ["haiku", "sonnet", "opus", "fable"]
    public static let efforts = ["low", "medium", "high", "xhigh", "max"]

    public init(
        modeles: [String: [String]], part5h: Int, partSemaine: Int?, simultanees: Int, machines: [String],
        surSaMachine: Bool, prompt: String, acces: AccesInvite, telemetrie: Bool
    ) {
        self.modeles = modeles
        self.part5h = part5h
        self.partSemaine = partSemaine
        self.simultanees = simultanees
        self.machines = machines
        self.surSaMachine = surSaMachine
        self.prompt = prompt
        self.acces = acces
        self.telemetrie = telemetrie
    }

    /// Réglages par défaut du chef ; `machine` (le nœud du chef), si donné, est la seule machine permise.
    public static func parDefaut(machine: String?) -> ReglagesInvite {
        ReglagesInvite(
            modeles: ["haiku": ["low", "medium", "high"], "sonnet": ["low", "medium", "high"]], part5h: 25,
            partSemaine: 25, simultanees: 2, machines: machine.map { [$0] } ?? [], surSaMachine: false, prompt: "",
            acces: .aucun, telemetrie: true)
    }

    /// Premier champ hors bornes (ou premier modèle mal formé), nil si les réglages sont valides.
    func defaut() -> String? {
        if !(0...100).contains(part5h) { return "part5h" }
        if let partSemaine, !(0...100).contains(partSemaine) { return "partSemaine" }
        if !(1...10).contains(simultanees) { return "simultanees" }
        if machines.count > 20 || machines.contains(where: { !Lu.estIdentifiant($0) }) { return "machines" }
        if prompt.utf16.count > 8000 { return "prompt" }
        return defautModeles()
    }

    private func defautModeles() -> String? {
        for (famille, efforts) in modeles {
            if !Self.familles.contains(famille) || efforts.count > 5 { return "modeles" }
            if Set(efforts).count != efforts.count { return "modeles" }
            if efforts.contains(where: { !Self.efforts.contains($0) }) { return "modeles" }
        }
        return nil
    }

    var valeurJSON: ValeurJSON {
        var objet: [String: ValeurJSON] = [:]
        objet["modeles"] = .objet(modeles.mapValues { liste in ValeurJSON.tableau(liste.map { ValeurJSON.texte($0) }) })
        objet["part5h"] = .nombre(Double(part5h))
        objet["partSemaine"] = partSemaine.map { ValeurJSON.nombre(Double($0)) } ?? .nul
        objet["simultanees"] = .nombre(Double(simultanees))
        objet["machines"] = .tableau(machines.map { ValeurJSON.texte($0) })
        objet["surSaMachine"] = .booleen(surSaMachine)
        objet["prompt"] = .texte(prompt)
        objet["acces"] = acces.valeurJSON
        objet["telemetrie"] = .booleen(telemetrie)
        return .objet(objet)
    }

    /// Lit des réglages depuis la charte ; un champ absent, mal typé ou hors bornes fait échouer la lecture.
    static func lire(_ valeur: ValeurJSON?) throws -> ReglagesInvite {
        let objet = try Lu.objet(valeur, "invite")
        let reglages = ReglagesInvite(
            modeles: try lireModeles(objet["modeles"]), part5h: try Lu.entier(objet["part5h"], "part5h"),
            partSemaine: try Lu.entierOuNul(objet["partSemaine"], "partSemaine"),
            simultanees: try Lu.entier(objet["simultanees"], "simultanees"),
            machines: try Lu.tableau(objet["machines"], "machines").map { try Lu.identifiant($0, "machines") },
            surSaMachine: try Lu.booleen(objet["surSaMachine"], "surSaMachine"),
            prompt: try Lu.texte(objet["prompt"], "prompt"), acces: try lireAcces(objet["acces"]),
            telemetrie: try Lu.booleen(objet["telemetrie"], "telemetrie"))
        if let cle = reglages.defaut() { throw Lu.illisible(cle) }
        return reglages
    }

    private static func lireModeles(_ valeur: ValeurJSON?) throws -> [String: [String]] {
        let objet = try Lu.objet(valeur, "modeles")
        var modeles: [String: [String]] = [:]
        for (famille, liste) in objet {
            modeles[famille] = try Lu.tableau(liste, "modeles").map { try Lu.texte($0, "modeles") }
        }
        return modeles
    }

    private static func lireAcces(_ valeur: ValeurJSON?) throws -> AccesInvite {
        let objet = try Lu.objet(valeur, "acces")
        return AccesInvite(
            remoteControl: try Lu.booleen(objet["remoteControl"], "acces"),
            terminaux: try Lu.booleen(objet["terminaux"], "acces"),
            sessionsAutres: try Lu.booleen(objet["sessionsAutres"], "acces"),
            modules: try Lu.booleen(objet["modules"], "acces"),
            fichiersHors: try Lu.booleen(objet["fichiersHors"], "acces"))
    }
}
