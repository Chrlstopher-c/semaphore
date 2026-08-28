import Foundation

/// Un poste chiffré de la fenêtre de contexte.
public struct PartContexte: Sendable, Decodable, Identifiable, Hashable {
    public var id: String { poste }
    /// `systeme`, `utilisateur`, `images`, `raisonnement`, `assistant`, `libre`.
    /// Non porté en `enum` : un poste inconnu ajouté côté serveur ferait échouer
    /// le décodage de TOUTE la mesure pour un libellé qu'on sait afficher tel quel.
    public let poste: String
    public let tokens: Int
    /// Fraction du contexte TOTAL, pas de la somme des postes.
    public let part: Double
}

/// Ce que la conversation occupe dans la fenêtre du modèle chargé, ou pourquoi
/// c'est inconnu.
///
/// `☠` `mesurable == false` n'est PAS une erreur : c'est l'absence de tokenizer
/// (aucun modèle chargé, moteur hors processus). Les champs chiffrés restent
/// alors à `nil` — un zéro ressemblerait à une mesure et laisserait croire à un
/// contexte libre. La route répond donc 200 dans ce cas, et l'app doit le
/// traiter comme un état normal.
public struct OccupationContexte: Sendable, Decodable {
    public let mesurable: Bool
    public let raison: String
    /// Le contexte SERVI, lu sur l'instance chargée — pas le contexte natif du
    /// modèle, qui peut le dépasser d'un ordre de grandeur (262 144 déclarés
    /// contre 32 768 appliqués).
    public let contexteTotal: Int?
    public let tokensMesures: Int?
    public let tokensLibres: Int?
    /// Tokens au-delà de la fenêtre : la conversation n'y tient plus.
    public let depassementTokens: Int?
    public let postes: [PartContexte]
    public let avertissements: [String]

    /// La part occupée, de 0 à 1. `nil` quand rien n'est mesurable — jamais 0,
    /// qui se lirait « le contexte est vide ».
    public var part: Double? {
        guard let tokensMesures, let contexteTotal, contexteTotal > 0 else { return nil }
        return min(Double(tokensMesures) / Double(contexteTotal), 1)
    }
}

/// Un message au format des moteurs (`{role, content}`), distinct du
/// `MessageChat` persisté du domaine `chat` : le domaine `inference` ne connaît
/// pas la persistance et mesure ce qu'on lui envoie.
struct MessageAMesurer: Encodable {
    let role: String
    let content: String
}

struct RequeteOccupation: Encodable {
    let promptSysteme: String
    let messages: [MessageAMesurer]
}

extension DepotModeles {
    /// `☠` Coûteuse : la requête envoie TOUS les messages. À n'émettre qu'à la
    /// fin d'un tour, jamais pendant la génération — une mesure par fragment
    /// ferait vingt requêtes par seconde à travers le tunnel.
    public func occupationContexte(
        promptSysteme: String, messages: [MessageChat]
    ) async throws -> OccupationContexte {
        let corps = try CodageJSON.encodeur().encode(RequeteOccupation(
            promptSysteme: promptSysteme,
            messages: messages.map {
                MessageAMesurer(role: $0.role.rawValue, content: $0.contenu)
            }
        ))
        return try await client.lire(
            OccupationContexte.self, "POST", "inference/contexte", corps: corps
        )
    }
}
