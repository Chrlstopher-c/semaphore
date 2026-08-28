import Foundation

/// Ce que rend une ÉCRITURE. Forme distincte des lectures, et volontairement :
/// `{ ok, effet, … }` n'est pas enveloppé, ne porte ni `pcOnline` ni `stale`.
///
/// Les traiter avec le même décodeur que les lectures produirait un « contrat
/// rompu » sur chaque geste réussi.
///
/// `effet` est une PHRASE écrite pour être affichée telle quelle. Elle dit
/// souvent ce que le code de statut ne dit pas : qu'une instruction a été
/// RETENUE parce que la mission est en pause, qu'il n'y avait rien à compacter,
/// qu'un tour ne générait rien. La remplacer par « Terminé » fait attendre à
/// l'opérateur une réaction qui ne viendra pas.
public struct AccuseEcriture: Decodable, Sendable {
    public let ok: Bool
    public let effet: String

    /// Approbation de mandat : l'équipe réellement créée.
    public let missionId: String?
    /// `POST /orchestrator/message` — la réponse de la session maître.
    public let reply: String?
    /// `/compact` — `false` n'est PAS une erreur : rien à compacter, ou tour en cours.
    public let compacted: Bool?
    /// `/interrompre` — `false` n'est PAS une erreur : le fil ne générait rien.
    public let interrupted: Bool?
    /// `/notifications/{id}/read` — `false` = déjà lue, ce qui reste un succès.
    public let marquee: Bool?
    /// `/notifications/read-all` — combien ont changé d'état.
    public let marquees: Int?
    /// `/conversations/{id}/machine` — la machine finalement rattachée.
    public let machine: String?
    /// Routes d'inspection — MÊME forme que la lecture, à dessein.
    public let inspection: InspectionApi?
    /// Création de fil — le fil complet, pour l'afficher sans second aller-retour.
    public let conversation: FilApi?
}

extension DecodeurContrat {
    /// Traduit une réponse HTTP d'ÉCRITURE.
    ///
    /// Un échec ici doit être VU : contrairement à une lecture, l'opérateur
    /// croirait sa mission arrêtée ou son équipe lancée. On ne fabrique jamais
    /// de succès par défaut, et on ne retombe jamais sur le miroir.
    public static func ecriture(statut: Int, corps: Data) -> Result<AccuseEcriture, ErreurApi> {
        guard (200...299).contains(statut) else {
            return .failure(ClassementErreur.classer(statut: statut, corps: corps))
        }
        do {
            return .success(try json.decode(AccuseEcriture.self, from: corps))
        } catch {
            return .failure(.contratRompu("accusé d'écriture illisible : \(error)"))
        }
    }
}
