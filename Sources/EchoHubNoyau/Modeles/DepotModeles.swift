import Foundation

/// L'interface publique du domaine `Modeles` : ce que le PC a sous la main, et
/// ce qu'il fait en ce moment.
public struct DepotModeles: Sendable {
    let client: ClientEchoHub

    public init(client: ClientEchoHub) {
        self.client = client
    }

    public func statut() async throws -> StatutInference {
        try await client.lire(StatutInference.self, "GET", "inference/etat")
    }

    public func registre() async throws -> [ModeleEnregistre] {
        try await client.lire([ModeleEnregistre].self, "GET", "models/registre")
    }
}

extension DepotModeles {
    /// Sonde le moteur MAINTENANT, là où `/etat` rend un état mémorisé.
    ///
    /// `☠` La distinction n'est pas cosmétique : un moteur mort n'apparaît pas
    /// dans `/etat`, qui continue d'affirmer « prêt ». C'est exactement le
    /// verdict déduit d'une fenêtre périmée — le bouton « Vérifier » du bandeau
    /// confirmait une fausse bonne nouvelle.
    public func sante() async throws -> SanteMoteur {
        try await client.lire(SanteMoteur.self, "GET", "inference/sante")
    }

    /// Attend la fin d'un chargement dans une fenêtre bornée CÔTÉ SERVEUR —
    /// exactement ce qu'il faut pour ne pas sonder en boucle depuis un téléphone.
    public func attendreEtat(delaiSecondes: Int) async throws -> StatutInference {
        try await client.lire(
            StatutInference.self, "GET", "inference/etat/attendre?delai_s=\(delaiSecondes)"
        )
    }

    /// Les métadonnées LUES dans l'en-tête GGUF — seule entrée valable du
    /// planificateur. `nul` quand le modèle n'est pas au format GGUF : rien
    /// n'est inventé à la place, et il n'y a alors rien à planifier.
    public func metadonnees(_ identifiant: String) async throws -> ValeurJSON {
        try await client.lireOpaque("GET", "models/registre/\(identifiant)/metadonnees")
    }

    /// Le profil matériel, mesuré à l'instant de l'appel. Jamais conservé : un
    /// plan calculé sur une mesure périmée est un plan faux.
    public func profilMachine() async throws -> ValeurJSON {
        try await client.lireOpaque("GET", "system/profil")
    }

    /// Applique le plan DÉJÀ calculé. Rend 202 et la main aussitôt :
    /// l'avancement se lit sur `/etat`.
    ///
    /// `☠` On repose le plan rendu, on n'en redemande pas un : replanifier ici
    /// produirait un AUTRE plan, la VRAM libre ayant pu changer entre-temps.
    public func charger(cheminModele: String, plan: ValeurJSON) async throws -> StatutInference {
        let corps = try CodageOpaque.encodeur().encode(
            ValeurJSON.objet(["chemin_modele": .texte(cheminModele), "plan": plan])
        )
        return try await client.lire(
            StatutInference.self, "POST", "inference/charger", corps: corps
        )
    }

    public func decharger() async throws -> StatutInference {
        try await client.lire(StatutInference.self, "POST", "inference/decharger")
    }

    /// Remonte un modèle en tête de liste. Un geste à un doigt, qui tient sur un
    /// téléphone.
    @discardableResult
    public func marquerFavori(_ identifiant: String, _ favori: Bool) async throws -> ModeleEnregistre {
        let corps = try CodageJSON.encodeur().encode(MajFavori(favori: favori))
        return try await client.lire(
            ModeleEnregistre.self, "PUT", "models/registre/\(identifiant)/favori", corps: corps
        )
    }
}

/// Ce que le moteur répond quand on le sonde à l'instant.
public struct SanteMoteur: Sendable, Decodable {
    public let disponible: Bool
    public let moteur: String?
    public let modele: String?
    public let latenceMs: Double?
    public let detail: String
}

struct MajFavori: Encodable {
    var favori: Bool
}
