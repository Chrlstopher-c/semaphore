import Foundation

/// Ce que le disque du PC contient réellement — y compris ce que le registre
/// refuse.
///
/// `☠` Le registre n'inscrit que le CHARGEABLE, et il a raison : un fichier
/// auxiliaire ou un téléchargement inachevé ne doit pas apparaître comme un
/// modèle utilisable. Mais le refuser au registre le rendait invisible ET
/// indestructible depuis l'interface — des gigaoctets que rien ne montrait et
/// que rien ne permettait d'effacer. C'est ce trou que cet écran ferme.
public struct DossierDisque: Sendable, Decodable, Identifiable, Hashable {
    public var id: String { dossier }
    public let dossier: String
    public let depot: String
    public let tailleOctets: Int
    public let nbFichiersPoids: Int
    /// Connu du registre, donc chargeable.
    public let inscrit: Bool
    /// Vide quand `inscrit` : il n'y a rien à expliquer d'un modèle qui marche.
    public let raison: String
    public let remediation: String

    public var tailleLisible: String { Mesures.octets(tailleOctets) }
}

/// Ce qu'une synchronisation a corrigé entre la base et le disque.
public struct ResumeSynchronisation: Sendable, Decodable {
    public let entreesSupprimees: [String]
    public let entreesAjoutees: [String]
    public let dossiersIgnores: [DossierIgnore]

    /// Une phrase, pas trois compteurs : sur un téléphone on lit le bilan, on
    /// ne l'additionne pas.
    public var bilan: String {
        var parties: [String] = []
        if !entreesAjoutees.isEmpty { parties.append("\(entreesAjoutees.count) inscrit(s)") }
        if !entreesSupprimees.isEmpty { parties.append("\(entreesSupprimees.count) retiré(s)") }
        if !dossiersIgnores.isEmpty { parties.append("\(dossiersIgnores.count) écarté(s)") }
        return parties.isEmpty ? "Le registre était déjà aligné sur le disque." : parties.joined(separator: ", ")
    }
}

/// Un dossier présent mais non inscriptible, et POURQUOI.
///
/// La raison ne vivait que dans les journaux du PC : l'écran annonçait sept
/// modèles sans dire que trois dossiers avaient été écartés, ni quoi en faire.
/// Un fichier auxiliaire et un téléchargement inachevé ne se corrigent pas de
/// la même façon.
public struct DossierIgnore: Sendable, Decodable, Identifiable, Hashable {
    public var id: String { dossier }
    public let dossier: String
    public let raison: String
    public let remediation: String
}

/// Ce qu'une suppression sur disque a réellement libéré.
public struct SuppressionDisque: Sendable, Decodable {
    public let dossier: String
    public let octetsLiberes: Int

    public var libere: String { Mesures.octets(octetsLiberes) }
}

extension DepotModeles {

    /// TOUT ce que la racine des modèles contient, inscrit ou non.
    public func disque() async throws -> [DossierDisque] {
        try await client.lire([DossierDisque].self, "GET", "models/disque")
    }

    /// `☠` Irréversible : les octets partent réellement du disque du PC. À ne
    /// jamais appeler sans une confirmation qui dit cette portée — c'est le
    /// seul geste de l'app qui détruit des données que rien ne réplique.
    @discardableResult
    public func supprimerDuDisque(_ dossier: String) async throws -> SuppressionDisque {
        try await client.lire(SuppressionDisque.self, "DELETE", "models/disque/\(dossier)")
    }

    /// Réaligne le registre sur le contenu réel du disque — le disque fait
    /// autorité, jamais l'inverse.
    @discardableResult
    public func synchroniserRegistre() async throws -> ResumeSynchronisation {
        try await client.lire(
            ResumeSynchronisation.self, "POST", "models/registre/synchronisation"
        )
    }
}
