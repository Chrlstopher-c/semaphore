import Foundation

// Responsabilité : le détail d'un appel d'outil, tel qu'on le déplie — titre, sections, et diff pour une édition.
// L'entrée est le JSON brut de l'outil : tronqué ou illisible, elle reste montrée telle quelle.

public struct DetailOutil: Sendable, Equatable {
    public struct Section: Sendable, Equatable {
        public let libelle: String
        public let contenu: String
        public let code: Bool
    }

    public struct LigneDiff: Sendable, Equatable {
        public enum Genre: String, Sendable, Equatable { case ajout, retrait, contexte }

        public let genre: Genre
        public let texte: String
    }

    public let titre: String
    public let sections: [Section]
    public let ajouts: Int?
    public let suppressions: Int?
    public let chemin: String?
    public let diff: [LigneDiff]?

    /// Un détail sans compteurs ni diff : titre et sections seulement.
    init(titre: String, sections: [Section], ajouts: Int? = nil, suppressions: Int? = nil, chemin: String? = nil,
         diff: [LigneDiff]? = nil) {
        self.titre = titre
        self.sections = sections
        self.ajouts = ajouts
        self.suppressions = suppressions
        self.chemin = chemin
        self.diff = diff
    }

    public static func depuis(_ appel: AppelOutil) -> DetailOutil {
        let objet = objetDe(appel.detail)
        guard let objet else { return brut(appel) }
        switch appel.nom {
        case "Bash": return bash(appel, objet)
        case "Edit": return edition(appel, objet)
        case "Write": return ecriture(appel, objet)
        default: return generique(appel, objet)
        }
    }

    private static func bash(_ appel: AppelOutil, _ objet: [String: Any]) -> DetailOutil {
        var sections: [Section] = []
        if let commande = texte(objet, "command") {
            sections.append(Section(libelle: "Commande", contenu: commande, code: true))
        }
        return DetailOutil(titre: texte(objet, "description") ?? appel.resume, sections: sections + sortie(appel))
    }

    private static func edition(_ appel: AppelOutil, _ objet: [String: Any]) -> DetailOutil {
        let anciennes = lignes(texte(objet, "old_string"))
        let nouvelles = lignes(texte(objet, "new_string"))
        let diff = anciennes.map { DetailOutil.LigneDiff(genre: .retrait, texte: $0) }
            + nouvelles.map { DetailOutil.LigneDiff(genre: .ajout, texte: $0) }
        return DetailOutil(titre: appel.resume, sections: sortie(appel), ajouts: nouvelles.count,
                           suppressions: anciennes.count, chemin: texte(objet, "file_path"), diff: diff)
    }

    private static func ecriture(_ appel: AppelOutil, _ objet: [String: Any]) -> DetailOutil {
        let contenu = lignes(texte(objet, "content"))
        return DetailOutil(titre: appel.resume, sections: sortie(appel), ajouts: contenu.count, suppressions: 0,
                           chemin: texte(objet, "file_path"),
                           diff: contenu.map { DetailOutil.LigneDiff(genre: .ajout, texte: $0) })
    }

    private static func generique(_ appel: AppelOutil, _ objet: [String: Any]) -> DetailOutil {
        let entree = DetailOutil.Section(libelle: "Entrée", contenu: jsonIndente(objet) ?? appel.detail, code: true)
        return DetailOutil(titre: appel.resume, sections: [entree] + sortie(appel))
    }

    /// Entrée illisible : une seule section « Entrée » avec le texte brut.
    private static func brut(_ appel: AppelOutil) -> DetailOutil {
        let entree = Section(libelle: "Entrée", contenu: appel.detail, code: true)
        return DetailOutil(titre: appel.resume, sections: [entree] + sortie(appel))
    }

    private static func sortie(_ appel: AppelOutil) -> [Section] {
        guard let resultat = appel.resultat else { return [] }
        return [Section(libelle: "Sortie", contenu: resultat.extrait, code: true)]
    }

    private static func objetDe(_ detail: String) -> [String: Any]? {
        guard let donnees = detail.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: donnees)) as? [String: Any]
    }

    private static func jsonIndente(_ objet: [String: Any]) -> String? {
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
        guard let donnees = try? JSONSerialization.data(withJSONObject: objet, options: options) else {
            return nil
        }
        return String(decoding: donnees, as: UTF8.self)
    }

    private static func texte(_ objet: [String: Any], _ cle: String) -> String? {
        guard let valeur = objet[cle] as? String, !valeur.isEmpty else { return nil }
        return valeur
    }

    private static func lignes(_ texte: String?) -> [String] {
        guard let texte, !texte.isEmpty else { return [] }
        return texte.components(separatedBy: "\n")
    }
}
