import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Ce que le relais du Pi sait de la tour (`GET /tour`) : le Pi reste allumé, la tour non.
///
/// Contrat : `echohub-mobile/Relais/README.md`. Le relais sonde lui-même (port ssh de la tour,
/// `/api/inference/etat` d'EchoHub) : l'iPhone ne voit que le relais.
public struct EtatTour: Sendable, Decodable, Equatable {
    public let tour: String
    public let echohub: String
    public let modele: ModeleTour?
    public let demarrage: String
    public let reveilEnvoyeLe: Date?
    public let mesureLe: Date?

    public init(
        tour: String, echohub: String, modele: ModeleTour? = nil, demarrage: String = "aucun",
        reveilEnvoyeLe: Date? = nil, mesureLe: Date? = nil
    ) {
        self.tour = tour
        self.echohub = echohub
        self.modele = modele
        self.demarrage = demarrage
        self.reveilEnvoyeLe = reveilEnvoyeLe
        self.mesureLe = mesureLe
    }
}

public struct ModeleTour: Sendable, Decodable, Equatable {
    public let etat: String
    public let nom: String?

    public init(etat: String, nom: String?) {
        self.etat = etat
        self.nom = nom
    }
}

/// L'état à peindre, déduit d'`EtatTour` : une seule vérité pour l'écran et ses boutons.
public enum PhaseTour: Sendable, Equatable {
    /// Tour éteinte, aucun réveil récent : bouton « Allumer ».
    case eteinte
    /// Réveil envoyé il y a moins de `delaiAllumage` : on attend que la tour réponde.
    case allumage
    /// Tour allumée mais EchoHub ne répond pas : bouton « Démarrer EchoHub ».
    case echohubArrete
    /// Démarrage d'EchoHub lancé par le relais, pas encore prêt.
    case demarrage
    /// Démarrage lancé et terminé en échec : le relais l'a vu, on le dit.
    case demarrageEchoue
    /// EchoHub répond ; `modele` = nom du modèle chargé, nil si aucun.
    case prete(modele: String?)

    /// Une tour met ~1 min à démarrer ; au-delà de 3 min sans réponse, le réveil a échoué.
    public static let delaiAllumage: TimeInterval = 180

    public static func depuis(_ etat: EtatTour, maintenant: Date = Date()) -> PhaseTour {
        if etat.echohub == "pret" {
            let charge = etat.modele?.etat == "pret" ? etat.modele?.nom : nil
            return .prete(modele: charge.map(Self.nomCourt))
        }
        if etat.tour == "allumee" {
            switch etat.demarrage {
            case "en_cours": return .demarrage
            case "echoue": return .demarrageEchoue
            default: return .echohubArrete
            }
        }
        if let reveil = etat.reveilEnvoyeLe, maintenant.timeIntervalSince(reveil) < delaiAllumage {
            return .allumage
        }
        return .eteinte
    }

    /// `org/depot::fichier.gguf` → `fichier` : le nom que Chris reconnaît.
    public static func nomCourt(_ identifiant: String) -> String {
        let fichier = identifiant.components(separatedBy: "::").last ?? identifiant
        let base = fichier.split(separator: "/").last.map(String.init) ?? fichier
        return base.hasSuffix(".gguf") ? String(base.dropLast(5)) : base
    }
}

extension ClientEchoHub {
    /// `GET /tour` sur le relais (hors `/api` : c'est le Pi qui répond, pas EchoHub).
    public func etatTour() async throws -> EtatTour {
        let donnees = try await routeRelais("GET", "tour")
        do {
            return try CodageJSON.decodeur().decode(EtatTour.self, from: donnees)
        } catch {
            throw ErreurRelais.reponseIllisible(String(describing: error))
        }
    }

    /// Paquet magique envoyé par le Pi. Sans effet si la tour est déjà allumée.
    public func reveillerTour() async throws {
        _ = try await routeRelais("POST", "tour/reveiller")
    }

    /// Démarre la pile EchoHub sur la tour (ssh à commande forcée côté Pi). Idempotent.
    public func demarrerEchoHub() async throws {
        _ = try await routeRelais("POST", "tour/echohub/demarrer")
    }

    /// Requête d'ouverture d'un aperçu d'app : à charger TELLE QUELLE dans la WebView.
    ///
    /// La WebView ne peut pas poser le Bearer sur les sous-requêtes de l'app ; cette première
    /// requête le porte, le relais répond par un cookie signé puis redirige vers `/`.
    public func requeteApercu(port: Int) throws -> URLRequest {
        var requete = try requeteRelais("GET", "apercu/ouvrir?port=\(port)")
        requete.cachePolicy = .reloadIgnoringLocalCacheData
        return requete
    }

    /// Même chose par le port DANS l'atelier (ce que rend `projets/{nom}/apercu`) : le relais le traduit.
    public func requeteApercu(atelier port: Int) throws -> URLRequest {
        var requete = try requeteRelais("GET", "apercu/ouvrir?atelier=\(port)")
        requete.cachePolicy = .reloadIgnoringLocalCacheData
        return requete
    }

    func routeRelais(_ methode: String, _ chemin: String, corps: Data? = nil) async throws -> Data {
        var requete = try requeteRelais(methode, chemin)
        if let corps {
            requete.httpBody = corps
            requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let donnees: Data
        let reponse: URLResponse
        do {
            (donnees, reponse) = try await URLSession.shared.data(for: requete)
        } catch {
            if ErreurRelais.vientDUneAnnulation(error) { throw ErreurRelais.annule }
            Journal.echec("relais \(methode) /\(chemin) échoué : \(error.localizedDescription)")
            throw ErreurRelais.injoignable(error.localizedDescription)
        }
        try Self.verifierStatut(reponse, donnees: donnees, chemin: chemin)
        return donnees
    }

    func requeteRelais(_ methode: String, _ chemin: String) throws -> URLRequest {
        let adresse = adresseCourante()
        guard let base = URL(string: adresse), base.host != nil else {
            throw ErreurRelais.adresseInvalide(adresse)
        }
        let morceaux = chemin.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        // `chemin` arrive déjà encodé (un nom de secret peut porter `/` ou `%`) : il est posé tel quel.
        var composants = URLComponents(url: base, resolvingAgainstBaseURL: false)
        if let racine = composants?.percentEncodedPath {
            composants?.percentEncodedPath = (racine.hasSuffix("/") ? String(racine.dropLast()) : racine)
                + "/" + morceaux[0]
        }
        if morceaux.count == 2 { composants?.percentEncodedQuery = String(morceaux[1]) }
        guard let url = composants?.url else { throw ErreurRelais.adresseInvalide(adresse) }
        var requete = URLRequest(url: url, timeoutInterval: Self.delaiRequeteSecondes)
        requete.httpMethod = methode
        let jeton = jetonCourant()
        if !jeton.isEmpty { requete.setValue("Bearer \(jeton)", forHTTPHeaderField: "Authorization") }
        return requete
    }
}
