import Foundation

// Responsabilité : les messages du protocole de l'aiguilleur et du lien chiffré, miroir de `commun/aiguilleur.ts` et
// `commun/federation.ts` (Quart). Un message hors protocole lève une erreur : jamais de valeur devinée.

enum ProtocoleAiguilleur {
    struct Membre: Equatable, Sendable {
        let id: String
        let enLigne: Bool
        /// « noeud » ou « appareil » ; absent chez un aiguilleur qui ne le transmet pas.
        var genre: String? = nil
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

    /// Cible d'un terminal de machine : le shell (dans un dossier, facultatif) ou une session tmux.
    enum CibleTerminal: Equatable, Sendable {
        case shell(dossier: String?)
        case tmux(String)
    }

    /// Messages du lien chiffré, miroir de `MessageChiffre` (Quart, commun/federation.ts). `codage` : base64 pour un
    /// corps binaire ; `morceaux` : le corps arrive en morceaux sous la même référence, avant ce message.
    enum DuLien: Equatable, Sendable {
        case api(ref: String, methode: String, chemin: String, corps: String?,
                 codage: String? = nil, type: String? = nil, morceaux: Int? = nil)
        case apiReponse(ref: String, statut: Int, corps: String,
                        codage: String? = nil, type: String? = nil, morceaux: Int? = nil)
        case revocation
        case morceau(ref: String, rang: Int, corps: String)
        case diffusionOuvrir, diffusionFermer, diffusionOuverte
        case diffusion(ref: String, corps: String, morceaux: Int?)
        case terminalPoste(ref: String, terminal: String, machine: String, cible: CibleTerminal,
                           colonnes: Int, lignes: Int)
        case terminalEntree(terminal: String, base64: String)
        case terminalTaille(terminal: String, colonnes: Int, lignes: Int)
        case terminalFermer(terminal: String)
        case terminalSortie(terminal: String, base64: String)
        case terminalFin(terminal: String, code: Int?)
        case reponse(ref: String, ok: Bool, raison: String?)
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
        let objet = try objetDuLien(message)
        return try JSONSerialization.data(withJSONObject: objet)
    }

    private static func objetDuLien(_ message: DuLien) throws -> [String: Any] {
        switch message {
        case let .api(ref, methode, chemin, corps, codage, type, morceaux):
            var objet: [String: Any] = ["t": "api", "ref": ref, "methode": methode, "chemin": chemin]
            if let corps { objet["corps"] = corps }
            return ajouter(objet, codage: codage, type: type, morceaux: morceaux)
        case let .apiReponse(ref, statut, corps, codage, type, morceaux):
            let objet: [String: Any] = ["t": "api_reponse", "ref": ref, "statut": statut, "corps": corps]
            return ajouter(objet, codage: codage, type: type, morceaux: morceaux)
        case .revocation: return ["t": "revocation"]
        case let .morceau(ref, rang, corps): return ["t": "morceau", "ref": ref, "rang": rang, "corps": corps]
        case .diffusionOuvrir: return ["t": "diffusion_ouvrir"]
        case .diffusionFermer: return ["t": "diffusion_fermer"]
        case .diffusionOuverte: return ["t": "diffusion_ouverte"]
        case let .diffusion(ref, corps, morceaux):
            return ajouter(["t": "diffusion", "ref": ref, "corps": corps], codage: nil, type: nil, morceaux: morceaux)
        case let .terminalPoste(ref, terminal, machine, cible, colonnes, lignes):
            return ["t": "terminal_poste", "ref": ref, "terminal": terminal, "machine": machine,
                    "cible": objetCible(cible), "colonnes": colonnes, "lignes": lignes]
        case let .terminalEntree(terminal, base64): return ["t": "terminal_entree", "terminal": terminal, "base64": base64]
        case let .terminalTaille(terminal, colonnes, lignes):
            return ["t": "terminal_taille", "terminal": terminal, "colonnes": colonnes, "lignes": lignes]
        case let .terminalFermer(terminal): return ["t": "terminal_fermer", "terminal": terminal]
        case let .terminalSortie(terminal, base64): return ["t": "terminal_sortie", "terminal": terminal, "base64": base64]
        case let .terminalFin(terminal, code):
            return ["t": "terminal_fin", "terminal": terminal, "code": code.map { $0 as Any } ?? NSNull()]
        case let .reponse(ref, ok, raison):
            var objet: [String: Any] = ["t": "reponse", "ref": ref, "ok": ok]
            if let raison { objet["raison"] = raison }
            return objet
        }
    }

    private static func ajouter(_ objet: [String: Any], codage: String?, type: String?, morceaux: Int?) -> [String: Any] {
        var sortie = objet
        if let codage { sortie["codage"] = codage }
        if let type { sortie["type"] = type }
        if let morceaux { sortie["morceaux"] = morceaux }
        return sortie
    }

    private static func objetCible(_ cible: CibleTerminal) -> [String: Any] {
        switch cible {
        case let .shell(dossier):
            return dossier.map { ["type": "shell", "dossier": $0] } ?? ["type": "shell"]
        case let .tmux(nom): return ["type": "tmux", "tmux": nom]
        }
    }

    static func decoderDuLien(_ octets: Data) throws -> DuLien {
        guard let objet = try objetJSON(octets) else { throw ErreurChiffrement("lien : message hors protocole") }
        return try decoderDuLien(objet)
    }

    private static func decoderDuLien(_ objet: [String: Any]) throws -> DuLien {
        let codage = objet["codage"] as? String
        let type = objet["type"] as? String
        let morceaux = objet["morceaux"] as? Int
        switch try chaine(objet, "t") {
        case "api":
            return .api(ref: try chaine(objet, "ref"), methode: try chaine(objet, "methode"),
                        chemin: try chaine(objet, "chemin"), corps: objet["corps"] as? String,
                        codage: codage, type: type, morceaux: morceaux)
        case "api_reponse":
            guard let statut = objet["statut"] as? Int else { throw ErreurChiffrement("statut absent") }
            return .apiReponse(ref: try chaine(objet, "ref"), statut: statut, corps: try chaine(objet, "corps"),
                               codage: codage, type: type, morceaux: morceaux)
        case "revocation": return .revocation
        case "morceau":
            return .morceau(ref: try chaine(objet, "ref"), rang: try entier(objet, "rang"),
                            corps: try chaine(objet, "corps"))
        case "diffusion_ouvrir": return .diffusionOuvrir
        case "diffusion_fermer": return .diffusionFermer
        case "diffusion_ouverte": return .diffusionOuverte
        case "diffusion":
            return .diffusion(ref: try chaine(objet, "ref"), corps: try chaine(objet, "corps"), morceaux: morceaux)
        case "terminal_poste":
            return .terminalPoste(ref: try chaine(objet, "ref"), terminal: try chaine(objet, "terminal"),
                                  machine: try chaine(objet, "machine"), cible: try decoderCible(objet),
                                  colonnes: try entier(objet, "colonnes"), lignes: try entier(objet, "lignes"))
        case "terminal_entree":
            return .terminalEntree(terminal: try chaine(objet, "terminal"), base64: try chaine(objet, "base64"))
        case "terminal_taille":
            return .terminalTaille(terminal: try chaine(objet, "terminal"), colonnes: try entier(objet, "colonnes"),
                                   lignes: try entier(objet, "lignes"))
        case "terminal_fermer":
            return .terminalFermer(terminal: try chaine(objet, "terminal"))
        case "terminal_sortie":
            return .terminalSortie(terminal: try chaine(objet, "terminal"), base64: try chaine(objet, "base64"))
        case "terminal_fin":
            return .terminalFin(terminal: try chaine(objet, "terminal"), code: objet["code"] as? Int)
        case "reponse":
            guard let ok = objet["ok"] as? Bool else { throw ErreurChiffrement("champ « ok » absent") }
            return .reponse(ref: try chaine(objet, "ref"), ok: ok, raison: objet["raison"] as? String)
        case let inconnu: throw MessageLienInconnu(type: inconnu)
        }
    }

    private static func decoderCible(_ objet: [String: Any]) throws -> CibleTerminal {
        guard let cible = objet["cible"] as? [String: Any] else { throw ErreurChiffrement("champ « cible » absent") }
        switch try chaine(cible, "type") {
        case "shell": return .shell(dossier: cible["dossier"] as? String)
        case "tmux": return .tmux(try chaine(cible, "tmux"))
        default: throw ErreurChiffrement("cible de terminal inconnue")
        }
    }

    private static func entier(_ objet: [String: Any], _ cle: String) throws -> Int {
        guard let valeur = objet[cle] as? Int else { throw ErreurChiffrement("champ « \(cle) » absent") }
        return valeur
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
        return try liste.map {
            Membre(id: try chaine($0, "id"), enLigne: ($0["enLigne"] as? Bool) ?? false, genre: $0["genre"] as? String)
        }
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

/// Un message bien formé et bien chiffré, mais d'un type que cet appareil ne connaît pas (nœud plus récent, message
/// de fédération égaré) : écarté sans fermer le canal — le flux en direct et les requêtes en vol continuent.
struct MessageLienInconnu: Error, Equatable {
    let type: String
}
