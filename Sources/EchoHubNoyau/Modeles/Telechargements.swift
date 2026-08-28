import Foundation

/// Le cycle de vie d'un transfert.
public enum EtatTelechargement: String, Sendable, Decodable, Equatable {
    case enAttente = "en_attente"
    case enCours = "en_cours"
    case termine
    /// Le processus est mort sans verdict — typiquement l'arrêt du backend. Les
    /// octets déjà écrits restent en place : relancer reprend là où ça s'est
    /// arrêté. Distinct d'`annule`, qui est une décision.
    case interrompu
    case annule
    case erreur

    public var actif: Bool { self == .enAttente || self == .enCours }

    public var libelle: String {
        switch self {
        case .enAttente: return "En attente"
        case .enCours: return "En cours"
        case .termine: return "Terminé"
        case .interrompu: return "Interrompu"
        case .annule: return "Annulé"
        case .erreur: return "Échec"
        }
    }
}

/// L'état d'un transfert, tel qu'il est diffusé et tel qu'il est persisté.
///
/// `☠` Chaque événement du flux porte un état COMPLET, pas un delta : un client
/// qui se branche en cours de route n'a rien à reconstituer. C'est ce qui rend
/// le suivi correct depuis un téléphone qu'on déverrouille au milieu d'un
/// transfert de douze gigaoctets.
public struct Telechargement: Sendable, Decodable, Identifiable, Equatable {
    public var id: String { identifiant }
    public let identifiant: String
    public let depot: String
    public let fichier: String?
    public let chemin: String
    public let etat: EtatTelechargement
    public let octetsRecus: Int
    /// `nil` tant que le Hub n'a pas annoncé les tailles. Mieux vaut PAS de
    /// pourcentage qu'un faux — c'est la règle du serveur, tenue ici.
    public let octetsTotaux: Int?
    public let erreur: String?
    public let remediation: String?
    /// Fraction transférée, plafonnée à 1, ou `nil` si le total est inconnu.
    /// Calculée par le serveur : on la relit, on ne la recalcule pas.
    public let progression: Double?

    public var actif: Bool { etat.actif }

    /// « 4,1 Go sur 8,2 Go », ou « 4,1 Go » quand le total n'est pas annoncé.
    /// Jamais « 4,1 Go sur 0 ».
    public var avancement: String {
        guard let octetsTotaux, octetsTotaux > 0 else { return Mesures.octets(octetsRecus) }
        return "\(Mesures.octets(octetsRecus)) sur \(Mesures.octets(octetsTotaux))"
    }

    /// Le nom court, celui qui distingue deux variantes du même dépôt.
    public var nomCourt: String {
        fichier ?? depot.split(separator: "/").last.map(String.init) ?? depot
    }
}

/// Ce qu'on demande à télécharger : un fichier précis, ou le dépôt entier si
/// `fichier` est omis.
struct DemandeTelechargement: Encodable {
    var depot: String
    var fichier: String?
    var revision: String = "main"
}

extension DepotModeles {

    public func telechargements() async throws -> [Telechargement] {
        try await client.lire([Telechargement].self, "GET", "models/telechargements")
    }

    /// Démarre le transfert et rend la main aussitôt (202) : la suite se lit
    /// sur le flux, jamais en sondant.
    @discardableResult
    public func demarrerTelechargement(
        depot: String, fichier: String? = nil, revision: String = "main"
    ) async throws -> Telechargement {
        let corps = try CodageJSON.encodeur().encode(
            DemandeTelechargement(depot: depot, fichier: fichier, revision: revision)
        )
        return try await client.lire(
            Telechargement.self, "POST", "models/telechargements", corps: corps
        )
    }

    public func etatTelechargement(_ identifiant: String) async throws -> Telechargement {
        try await client.lire(
            Telechargement.self, "GET", "models/telechargements/\(identifiant)"
        )
    }

    /// `☠` Le défaut CONSERVE les octets déjà écrits, et c'est le bon défaut :
    /// un transfert de plusieurs gigaoctets doit pouvoir reprendre plutôt que
    /// repartir de zéro. `supprimerFichiers` est le geste explicite qui les jette.
    @discardableResult
    public func annulerTelechargement(
        _ identifiant: String, supprimerFichiers: Bool = false
    ) async throws -> Telechargement {
        try await client.lire(
            Telechargement.self, "DELETE",
            "models/telechargements/\(identifiant)?supprimer_fichiers=\(supprimerFichiers)"
        )
    }

    /// Reprend un transfert interrompu là où il s'était arrêté.
    @discardableResult
    public func relancerTelechargement(_ identifiant: String) async throws -> Telechargement {
        try await client.lire(
            Telechargement.self, "POST", "models/telechargements/\(identifiant)/relance"
        )
    }
}
