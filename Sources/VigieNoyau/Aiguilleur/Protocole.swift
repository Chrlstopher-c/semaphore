import Foundation

// Responsabilité : les messages du protocole de l'aiguilleur et du lien chiffré, miroir de `commun/aiguilleur.ts` et
// `commun/federation.ts` (Quart). Un message hors protocole lève une erreur : jamais de valeur devinée.

enum ProtocoleAiguilleur {
    struct Membre: Equatable, Sendable {
        let id: String
        let enLigne: Bool
    }

    /// Messages d'un membre vers l'aiguilleur.
    enum VersAiguilleur: Equatable, Sendable {
        case ouvrir(canal: String, vers: String)
        case accepter(canal: String)
        case refuser(canal: String)
        case fermer(canal: String)
        case donnees(canal: String, charge: String)
    }

    /// Messages de l'aiguilleur vers un membre.
    enum DeAiguilleur: Equatable, Sendable {
        case ouvrir(canal: String, de: String)
        case accepter(canal: String)
        case refuser(canal: String)
        case fermer(canal: String)
        case donnees(canal: String, charge: String)
        case presence([Membre])
        case erreur(canal: String?, motif: String)
    }

    /// Messages en clair d'un canal : présentation, décision, enveloppe de poignée, trame chiffrée.
    enum EnClair: Equatable, Sendable {
        case presentation(identite: String, nom: String, genre: String)
        case accord
        case refus(raison: String)
        case poignee(Chiffrement.MessageInitial)
        case poigneeReponse(Chiffrement.MessageReponse)
        case chiffre(trame: String)
    }

    /// Messages de l'API clients, chiffrés dans le canal : requête, réponse, révocation.
    enum DuLien: Equatable, Sendable {
        case api(ref: String, methode: String, chemin: String, corps: String?)
        case apiReponse(ref: String, statut: Int, corps: String)
        case revocation
    }

    static let tailleMaxClair = 600_000

    // MARK: - Aiguilleur

    static func encoder(_ message: VersAiguilleur) throws -> String {
        var objet: [String: Any]
        switch message {
        case let .ouvrir(canal, vers): objet = ["t": "ouvrir", "canal": canal, "vers": vers]
        case let .accepter(canal): objet = ["t": "accepter", "canal": canal]
        case let .refuser(canal): objet = ["t": "refuser", "canal": canal]
        case let .fermer(canal): objet = ["t": "fermer", "canal": canal]
        case let .donnees(canal, charge): objet = ["t": "donnees", "canal": canal, "charge": charge]
        }
        return try texte(objet)
    }

    static func decoderDeAiguilleur(_ texte: String) throws -> DeAiguilleur {
        let objet = try lire(texte)
        switch try chaine(objet, "t") {
        case "ouvrir": return .ouvrir(canal: try chaine(objet, "canal"), de: try chaine(objet, "de"))
        case "accepter": return .accepter(canal: try chaine(objet, "canal"))
        case "refuser": return .refuser(canal: try chaine(objet, "canal"))
        case "fermer": return .fermer(canal: try chaine(objet, "canal"))
        case "donnees": return .donnees(canal: try chaine(objet, "canal"), charge: try chaine(objet, "charge"))
        case "presence": return .presence(try membres(objet))
        case "erreur": return .erreur(canal: objet["canal"] as? String, motif: try chaine(objet, "motif"))
        default: throw ErreurChiffrement("aiguilleur : message hors protocole")
        }
    }

    // MARK: - Canal en clair

    static func encoder(_ message: EnClair) throws -> String {
        switch message {
        case let .presentation(identite, nom, genre):
            return try texte(["t": "presentation", "identite": identite, "nom": nom, "genre": genre])
        case .accord: return try texte(["t": "accord"])
        case let .refus(raison): return try texte(["t": "refus", "raison": raison])
        case let .poignee(m): return try texte(["t": "poignee", "m": objet(m)])
        case let .poigneeReponse(m): return try texte(["t": "poignee-reponse", "m": objet(m)])
        case let .chiffre(trame): return try texte(["t": "chiffre", "trame": trame])
        }
    }

    static func decoderEnClair(_ texte: String) throws -> EnClair {
        let objet = try lire(texte)
        switch try chaine(objet, "t") {
        case "presentation":
            return .presentation(identite: try chaine(objet, "identite"), nom: try chaine(objet, "nom"),
                                 genre: (objet["genre"] as? String) ?? "noeud")
        case "accord": return .accord
        case "refus": return .refus(raison: (objet["raison"] as? String) ?? "")
        case "poignee": return .poignee(try decoderObjet(objet, "m"))
        case "poignee-reponse": return .poigneeReponse(try decoderObjet(objet, "m"))
        case "chiffre": return .chiffre(trame: try chaine(objet, "trame"))
        default: throw ErreurChiffrement("canal : message hors protocole")
        }
    }

    // MARK: - Lien chiffré (contenu clair d'une trame)

    static func encoder(_ message: DuLien) throws -> Data {
        switch message {
        case let .api(ref, methode, chemin, corps):
            var objet: [String: Any] = ["t": "api", "ref": ref, "methode": methode, "chemin": chemin]
            if let corps { objet["corps"] = corps }
            return try JSONSerialization.data(withJSONObject: objet)
        case let .apiReponse(ref, statut, corps):
            let objet: [String: Any] = ["t": "api_reponse", "ref": ref, "statut": statut, "corps": corps]
            return try JSONSerialization.data(withJSONObject: objet)
        case .revocation:
            return try JSONSerialization.data(withJSONObject: ["t": "revocation"])
        }
    }

    static func decoderDuLien(_ octets: Data) throws -> DuLien {
        guard let objet = try objetJSON(octets) else { throw ErreurChiffrement("lien : message hors protocole") }
        switch try chaine(objet, "t") {
        case "api":
            return .api(ref: try chaine(objet, "ref"), methode: try chaine(objet, "methode"),
                        chemin: try chaine(objet, "chemin"), corps: objet["corps"] as? String)
        case "api_reponse":
            guard let statut = objet["statut"] as? Int else { throw ErreurChiffrement("statut absent") }
            return .apiReponse(ref: try chaine(objet, "ref"), statut: statut, corps: try chaine(objet, "corps"))
        case "revocation": return .revocation
        default: throw ErreurChiffrement("lien : message hors protocole")
        }
    }

    // MARK: - Utilitaires JSON

    private static func lire(_ texte: String) throws -> [String: Any] {
        guard let objet = try objetJSON(Data(texte.utf8)) else { throw ErreurChiffrement("message non objet") }
        return objet
    }

    private static func objetJSON(_ octets: Data) throws -> [String: Any]? {
        do {
            return try JSONSerialization.jsonObject(with: octets) as? [String: Any]
        } catch {
            throw ErreurChiffrement("JSON illisible : \(error.localizedDescription)")
        }
    }

    private static func chaine(_ objet: [String: Any], _ cle: String) throws -> String {
        guard let valeur = objet[cle] as? String else { throw ErreurChiffrement("champ « \(cle) » absent") }
        return valeur
    }

    private static func membres(_ objet: [String: Any]) throws -> [Membre] {
        guard let liste = objet["membres"] as? [[String: Any]] else { throw ErreurChiffrement("membres absents") }
        return try liste.map { Membre(id: try chaine($0, "id"), enLigne: ($0["enLigne"] as? Bool) ?? false) }
    }

    private static func texte(_ objet: [String: Any]) throws -> String {
        let octets = try JSONSerialization.data(withJSONObject: objet)
        guard let texte = String(data: octets, encoding: .utf8) else { throw ErreurChiffrement("encodage refusé") }
        return texte
    }

    private static func objet<T: Encodable>(_ valeur: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(valeur))
    }

    private static func decoderObjet<T: Decodable>(_ objet: [String: Any], _ cle: String) throws -> T {
        guard let imbrique = objet[cle] else { throw ErreurChiffrement("champ « \(cle) » absent") }
        let octets = try JSONSerialization.data(withJSONObject: imbrique)
        return try JSONDecoder().decode(T.self, from: octets)
    }
}
