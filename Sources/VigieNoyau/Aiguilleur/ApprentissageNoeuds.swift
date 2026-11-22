import Foundation

// Responsabilité : la lecture de la liste des nœuds servie par un nœud (`GET /api/appareils/noeuds`) et
// l'apprentissage des identités qu'elle porte. Premier apprentissage gagne : une identité déjà connue n'est
// jamais écrasée, un désaccord est journalisé sans la clé. La liste n'appaire rien à elle seule : elle apprend
// des clés, que la poignée vérifiera. Soi-même et les entrées mal formées sont ignorés.

enum ApprentissageNoeuds {
    /// Un nœud de la liste. Une entrée mal formée échoue à la lecture, sans effet sur les autres.
    struct Entree: Decodable, Equatable, Sendable {
        private static let chiffresHexa = Set("0123456789abcdef")

        let id: String
        let nom: String?
        let identite: String

        init(from decoder: Decoder) throws {
            let champs = try decoder.container(keyedBy: CodingKeys.self)
            let identifiant = try champs.decode(String.self, forKey: .id)
            guard identifiant.count == 12, identifiant.allSatisfy({ Entree.chiffresHexa.contains($0) }) else {
                throw ErreurAiguilleur("identifiant de nœud mal formé")
            }
            id = identifiant
            nom = try champs.decodeIfPresent(String.self, forKey: .nom)
            identite = try champs.decode(String.self, forKey: .identite)
        }

        private enum CodingKeys: String, CodingKey { case id, nom, identite }
    }

    /// Une entrée lue sans jamais échouer : une entrée mal formée devient nil, les autres restent.
    private struct Tolere: Decodable {
        let entree: Entree?

        init(from decoder: Decoder) throws {
            entree = try? Entree(from: decoder)
        }
    }

    private struct Reponse: Decodable {
        let noeuds: [Tolere]
    }

    /// Les entrées valides de la liste ; nil si le corps n'a pas la forme attendue.
    static func lire(_ corps: String) -> [Entree]? {
        do {
            let reponse = try JSONDecoder().decode(Reponse.self, from: Data(corps.utf8))
            return reponse.noeuds.compactMap(\.entree)
        } catch {
            Trace.erreur("aiguilleur", "liste des nœuds illisible, ignorée", error)
            return nil
        }
    }

    /// Apprend les identités inconnues dans `noeuds` ; renvoie les identifiants appris (vide : rien n'a changé).
    static func fusionner(
        _ entrees: [Entree], dans noeuds: inout [String: NoeudConnu], moi: String, identiteMoi: String?
    ) -> [String] {
        var appris: [String] = []
        for entree in entrees where entree.id != moi {
            guard let texte = identiteValide(entree.identite) else {
                Trace.info("aiguilleur", "clé illisible pour le nœud \(entree.id), entrée ignorée")
                continue
            }
            guard texte != identiteMoi else { continue }
            if let connue = noeuds[entree.id]?.identite {
                if connue != texte {
                    let motif = "désaccord sur l'identité du nœud \(entree.id) : clé de la liste ignorée"
                    Trace.info("aiguilleur", motif)
                }
                continue
            }
            noeuds[entree.id] = NoeudConnu(identite: texte, nom: entree.nom ?? noeuds[entree.id]?.nom)
            appris.append(entree.id)
        }
        return appris
    }

    /// La clé sous sa forme canonique si elle est valide ; nil sinon.
    private static func identiteValide(_ texte: String) -> String? {
        guard let identite = try? Chiffrement.Identites.importer(texte) else { return nil }
        return Chiffrement.Identites.exporter(identite)
    }
}
