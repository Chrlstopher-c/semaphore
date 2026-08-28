import Foundation

/// La recherche de modèles sur le Hub Hugging Face.
///
/// `☠` Tout ce qui revient d'ici est **annoncé**, jamais mesuré. Le Hub n'a pas
/// de champ « capacités » : `capacitesDeduites` est une conclusion tirée de ses
/// déclarations, et chaque entrée porte les indices qui l'ont produite. Une
/// interface qui les afficherait comme un fait vérifié mentirait sciemment —
/// c'est la distinction que la v1 perdait, et elle coûtait des téléchargements
/// de plusieurs gigaoctets pour un modèle qui ne savait pas ce qu'on croyait.
public struct PageRecherche: Sendable, Decodable {
    public let resultats: [ResultatDepot]
    public let page: Int
    public let taillePage: Int
    /// Il n'y a rien après. Le seul moyen honnête de savoir s'il faut proposer
    /// « la suite » — le Hub n'annonce pas de total fiable.
    public let finAtteinte: Bool
}

/// Un dépôt tel que le Hub le décrit, complété par ce que le PC sait déjà.
public struct ResultatDepot: Sendable, Decodable, Identifiable, Hashable {
    public var id: String { depot }
    public let depot: String
    public let nom: String
    public let auteur: String?
    public let telechargements: Int?
    public let mentions: Int?
    public let modifieLe: String?
    /// Le dépôt exige une acceptation de licence sur le Hub. Un transfert
    /// lancé dessus échouera : le dire avant vaut mieux qu'après.
    public let gated: Bool
    public let tache: String?
    public let etiquettes: [String]
    public let formats: [String]
    public let fichiersGguf: [FichierDepot]
    public let tailleTotaleOctets: Int?
    public let annonce: MetadonneesAnnoncees
    public let capacitesDeduites: [CapaciteDeduite]
    /// Déjà sur le disque du PC. Évite de retélécharger douze gigaoctets.
    public let dejaTelecharge: Bool

    public var tailleLisible: String? {
        tailleTotaleOctets.map(Mesures.octets)
    }
}

/// Un fichier du dépôt. `etiquette` vient du NOM DE FICHIER : c'est une
/// intention de son auteur, pas un fait vérifié.
public struct FichierDepot: Sendable, Decodable, Identifiable, Hashable {
    public var id: String { nom }
    public let nom: String
    public let tailleOctets: Int?
    public let etiquette: String?

    public var tailleLisible: String? { tailleOctets.map(Mesures.octets) }
}

/// Ce que le Hub dit du modèle sans qu'on ait ouvert un seul octet de poids.
/// Sert à CHOISIR un dépôt, jamais à dimensionner un chargement.
public struct MetadonneesAnnoncees: Sendable, Decodable, Hashable {
    public let architecture: String?
    public let contexte: Int?
    public let nbParametres: Int?
}

/// Les critères de tri acceptés par l'API du Hub.
public enum TriRecherche: String, Sendable, CaseIterable {
    case telechargements = "downloads"
    case mentions = "likes"
    case tendance = "trending_score"
    case modification = "last_modified"

    public var libelle: String {
        switch self {
        case .telechargements: return "Téléchargements"
        case .mentions: return "Mentions"
        case .tendance: return "Tendance"
        case .modification: return "Récents"
        }
    }
}

/// Ce qu'on demande au Hub. Assemblé en chaîne de requête par `chemin`, qui est
/// pur et donc éprouvable sans réseau.
public struct DemandeRecherche: Sendable, Equatable {
    public var requete: String
    /// `gguf` par défaut : c'est le seul format que le planificateur sait
    /// charger aujourd'hui, et proposer le reste ferait télécharger pour rien.
    public var formats: [String]
    /// Se combinent en ET : deux capacités ne gardent que les dépôts qui
    /// laissent entendre les deux.
    public var capacites: [String]
    public var tri: TriRecherche
    public var page: Int
    public var taillePage: Int

    public init(
        requete: String = "", formats: [String] = ["gguf"], capacites: [String] = [],
        tri: TriRecherche = .telechargements, page: Int = 0, taillePage: Int = 20
    ) {
        self.requete = requete
        self.formats = formats
        self.capacites = capacites
        self.tri = tri
        self.page = page
        self.taillePage = taillePage
    }

    /// `☠` Les paramètres répétés (`formats`, `capacites`) s'écrivent en
    /// répétant la CLÉ, jamais en joignant par des virgules : FastAPI lit une
    /// `list[…]` de cette façon, et une virgule serait avalée dans une seule
    /// valeur qu'aucun format ne reconnaît.
    ///
    /// `☠` La chaîne est pourcent-encodée ICI : `ClientEchoHub` pose la requête
    /// telle quelle (`percentEncodedQuery`) parce qu'il ne peut pas savoir ce
    /// qui, dans un chemin, est déjà encodé.
    public var chemin: String {
        var couples: [(String, String)] = [
            ("requete", requete), ("tri", tri.rawValue), ("ordre", "desc"),
            ("page", "\(page)"), ("taille_page", "\(taillePage)"),
        ]
        couples += formats.map { ("formats", $0) }
        couples += capacites.map { ("capacites", $0) }
        let chaine = couples
            .map { "\($0.0)=\(Self.encoder($0.1))" }
            .joined(separator: "&")
        return "models/recherche?\(chaine)"
    }

    /// Jeu de caractères volontairement étroit : `+`, `&` et `=` sont légaux
    /// dans un composant d'URL mais changent le sens d'une chaîne de requête.
    /// `urlQueryAllowed` les laisse passer — d'où la liste explicite.
    static func encoder(_ valeur: String) -> String {
        var autorises = CharacterSet.alphanumerics
        autorises.insert(charactersIn: "-._~")
        return valeur.addingPercentEncoding(withAllowedCharacters: autorises) ?? ""
    }
}

extension DepotModeles {

    public func rechercherDepots(_ demande: DemandeRecherche) async throws -> PageRecherche {
        try await client.lire(PageRecherche.self, "GET", demande.chemin)
    }

    /// La fiche complète d'un dépôt, avec la liste de ses fichiers de poids.
    /// C'est là qu'on choisit LA variante à télécharger — un dépôt GGUF en
    /// porte couramment dix, de Q2 à F16, et la différence est de vingt Go.
    public func ficheDepot(_ depot: String) async throws -> ResultatDepot {
        try await client.lire(ResultatDepot.self, "GET", "models/depots/\(depot)")
    }
}
