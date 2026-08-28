import Foundation

/// Ce qui peut rater entre l'iPhone et le PC, dit en français et actionnable.
///
/// `☠` Le message est destiné à être AFFICHÉ. Une erreur qui dit « erreur 500 »
/// n'apprend rien à quelqu'un qui tient son téléphone dans le métro ; celles-ci
/// disent où la chaîne a cassé — le relais, l'authentification, EchoHub, le
/// modèle — parce que ce sont quatre maillons distincts et qu'on ne les répare
/// pas de la même façon.
public enum ErreurRelais: Error, Sendable, Equatable {
    case adresseInvalide(String)
    case injoignable(String)
    case refuse
    case aucunModelePret
    /// Le PC génère DÉJÀ sur cette conversation. Rien n'est cassé : le modèle
    /// est chargé et il travaille.
    case generationEnCours
    /// Un refus que l'app ne traite pas spécialement : on rend alors ce que le
    /// serveur a écrit, message ET remède, plutôt qu'un nombre.
    case serveur(statut: Int, message: String, remede: String?)
    case reponseIllisible(String)

    public var libelle: String {
        switch self {
        case .adresseInvalide(let adresse):
            return "Adresse de relais invalide : « \(adresse) »."
        case .injoignable(let detail):
            return "Relais injoignable — \(detail)"
        case .refuse:
            return "Jeton refusé par le relais."
        case .aucunModelePret:
            return "Aucun modèle chargé sur le PC."
        case .generationEnCours:
            return "Une réponse est déjà en cours sur cette conversation."
        case .serveur(let statut, let message, _):
            return message.isEmpty ? "Le serveur a répondu \(statut)." : message
        case .reponseIllisible(let detail):
            return "Réponse illisible : \(detail)"
        }
    }

    /// Ce qu'il y a à faire, quand il y a quelque chose à faire.
    public var remede: String? {
        switch self {
        case .adresseInvalide, .injoignable:
            return "Vérifie l'adresse dans Réglages, et que le PC est allumé."
        case .refuse:
            return "Vérifie le jeton dans Réglages."
        case .aucunModelePret:
            // L'app a trois onglets — Fil, Conversations, Machine. Le remède
            // désignait « l'onglet Modèles », qui n'a jamais existé.
            return "Charge un modèle depuis l'onglet Machine."
        case .generationEnCours:
            return "Attends la fin, ou appuie sur Arrêter."
        case .serveur(_, _, let remede):
            return remede
        case .reponseIllisible:
            return nil
        }
    }
}

/// Le corps d'erreur que FastAPI et le relais écrivent tous les deux :
/// `{"detail": {"code", "message", "remediation"}}`.
public struct DetailErreurServeur: Sendable, Equatable {
    public let code: String?
    public let message: String
    public let remediation: String?

    public init(code: String?, message: String, remediation: String?) {
        self.code = code
        self.message = message
        self.remediation = remediation
    }
}

/// Traduit un refus HTTP en `ErreurRelais`.
///
/// `☠` Le CODE fait foi, jamais le statut seul — et c'est la correction la plus
/// coûteuse de l'audit. `409` valait `aucunModelePret`, ce qui est vrai sur
/// `POST /api/inference/generer` (route que cette app n'appelle JAMAIS) et
/// exactement faux sur la route `chat` qu'elle utilise, où `409` est
/// `generation_deja_en_cours` : le modèle est chargé, et il travaille. Après
/// une coupure de flux, l'app annonçait donc « Aucun modèle chargé » au moment
/// précis où le modèle générait.
///
/// Pur : aucune requête, aucun état. C'est ce qui le rend éprouvable par
/// `swift test`, sans réseau ni appareil.
public enum LectureRefus {
    public static func erreur(statut: Int, donnees: Data) -> ErreurRelais {
        let detail = lire(donnees)
        switch detail?.code {
        case "jeton_refuse":
            return .refuse
        case "generation_deja_en_cours":
            return .generationEnCours
        case "moteur_indisponible", "aucun_modele_pret":
            return .aucunModelePret
        default:
            break
        }
        // Le statut ne sert plus que de dernier recours, pour les refus posés
        // par un maillon qui n'écrit pas de code — un proxy, le tunnel.
        if statut == 401 || statut == 403 { return .refuse }
        return .serveur(
            statut: statut, message: detail?.message ?? "", remede: detail?.remediation
        )
    }

    /// `detail` vaut soit une chaîne (`HTTPException` nue), soit l'objet du
    /// contrat `EchoHubError.to_dict()`. Les deux formes existent en vrai.
    public static func lire(_ donnees: Data) -> DetailErreurServeur? {
        guard let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any],
              let detail = objet["detail"] else { return nil }
        if let texte = detail as? String {
            return DetailErreurServeur(code: nil, message: texte, remediation: nil)
        }
        guard let dictionnaire = detail as? [String: Any] else { return nil }
        return DetailErreurServeur(
            code: dictionnaire["code"] as? String,
            message: dictionnaire["message"] as? String ?? "",
            remediation: (dictionnaire["remediation"] as? String).flatMap {
                // Le backend écrit toujours la clé, parfois vide. Une chaîne
                // vide affichée sous un message d'erreur est une ligne blanche
                // inexpliquée : c'est une absence, pas un remède.
                $0.isEmpty ? nil : $0
            }
        )
    }
}
