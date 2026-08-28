import Foundation

/// Ce qu'on peut savoir d'un modèle déjà présent sur le disque du PC :
/// capacités déduites, cohérence entre ce qu'il déclare et ce qu'il contient.
///
/// `☠` Deux natures de savoir qui ne doivent JAMAIS se confondre, et c'est la
/// distinction que le backend prend soin de préserver :
/// - une capacité est **déduite** — une conclusion tracée, avec ses indices ;
/// - une métadonnée GGUF est **lue** dans l'en-tête du fichier.
/// L'interface doit les présenter différemment, sinon elle affiche une
/// déduction comme un fait vérifié, ce qui est un mensonge par mise en forme.
public struct CapaciteDeduite: Sendable, Decodable, Identifiable, Hashable {
    public var id: String { capacite }
    /// `raisonnement`, `appel_outils`, `vision`, `code`… Non porté en `enum` :
    /// une capacité ajoutée côté serveur ferait échouer le décodage de TOUTE la
    /// liste pour un libellé qu'on sait afficher tel quel.
    public let capacite: String
    public let indices: [IndiceCapacite]
}

/// D'où vient une déduction. Toutes ces sources sont DÉCLARATIVES : aucune
/// n'est une lecture de poids.
public struct IndiceCapacite: Sendable, Decodable, Hashable {
    public let source: String
    public let valeur: String
}

/// Le vocabulaire des capacités, publié par le serveur pour que l'interface
/// n'en recopie pas une liste qui finirait par diverger de celle qui filtre.
public struct DefinitionCapacite: Sendable, Decodable, Identifiable, Hashable {
    public var id: String { capacite }
    public let capacite: String
    public let libelle: String
    public let definition: String
}

/// Gravité d'un écart. `bloquant` signifie : le chargement échouera, inutile
/// d'essayer.
public enum NiveauIncoherence: String, Sendable, Decodable {
    case avertissement
    case bloquant
}

/// Un écart précis entre ce qui est déclaré et ce qui est présent.
public struct Incoherence: Sendable, Decodable, Identifiable, Hashable {
    public var id: String { code }
    public let code: String
    public let niveau: NiveauIncoherence
    public let message: String
    public let remediation: String
}

/// Le résultat d'une vérification. `chargeable` est ce qu'une interface doit
/// regarder — le reste explique pourquoi.
///
/// `☠` `chargeable` est une `@property` Python, donc NON sérialisée : elle se
/// recalcule ici à partir des niveaux reçus, pas d'un champ absent qui vaudrait
/// silencieusement `false`.
public struct RapportCoherence: Sendable, Decodable {
    public let chemin: String
    public let format: String?
    public let incoherences: [Incoherence]

    public var bloquantes: [Incoherence] {
        incoherences.filter { $0.niveau == .bloquant }
    }

    public var chargeable: Bool { bloquantes.isEmpty }
}

/// Ce que le serveur répond quand on retire une entrée du registre.
public struct ResultatOubli: Sendable, Decodable {
    public let oublie: Bool
}

extension DepotModeles {

    public func modele(_ identifiant: String) async throws -> ModeleEnregistre {
        try await client.lire(ModeleEnregistre.self, "GET", "models/registre/\(identifiant)")
    }

    /// Capacités DÉDUITES, chacune avec les indices qui l'ont produite. Une
    /// liste vide dit que rien n'est reconnaissable localement — PAS que le
    /// modèle est dépourvu de ces capacités.
    public func capacites(_ identifiant: String) async throws -> [CapaciteDeduite] {
        try await client.lire(
            [CapaciteDeduite].self, "GET", "models/registre/\(identifiant)/capacites"
        )
    }

    public func definitionsCapacites() async throws -> [DefinitionCapacite] {
        try await client.lire([DefinitionCapacite].self, "GET", "models/capacites")
    }

    /// Confronte ce que le modèle déclare à ce qu'il contient réellement. C'est
    /// la réponse à « pourquoi le planificateur refuse-t-il ce fichier ? ».
    public func coherence(_ identifiant: String) async throws -> RapportCoherence {
        try await client.lire(
            RapportCoherence.self, "GET", "models/registre/\(identifiant)/coherence"
        )
    }

    /// Retire l'entrée du registre. `☠` Les FICHIERS restent sur le disque,
    /// délibérément : oublier n'est pas supprimer, et l'interface doit le dire
    /// pour que le geste destructif reste le seul geste destructif.
    @discardableResult
    public func oublier(_ identifiant: String) async throws -> ResultatOubli {
        try await client.lire(ResultatOubli.self, "DELETE", "models/registre/\(identifiant)")
    }
}
