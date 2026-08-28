import Foundation

/// Construit un corps `multipart/form-data`.
///
/// `☠` Écrit à la main, et c'est voulu : `URLSession` n'en fabrique aucun, et
/// la seule alternative serait une dépendance externe — que ce projet
/// s'interdit. Le format tient en dix lignes, mais il ne pardonne pas : une
/// terminaison de ligne en `\n` au lieu de `\r\n` fait rendre un `422` par un
/// serveur qui ne dira jamais pourquoi. D'où un type pur, éprouvé par
/// `swift test`, plutôt que des `String` concaténées dans une vue.
public struct CorpsMultipart {
    /// La frontière. Aléatoire par défaut : elle ne doit apparaître dans aucune
    /// des parties, et un octet de photo peut contenir n'importe quoi.
    public let frontiere: String
    private var donnees = Data()

    public init(frontiere: String = "echohub-" + UUID().uuidString) {
        self.frontiere = frontiere
    }

    public var typeContenu: String { "multipart/form-data; boundary=\(frontiere)" }

    /// Un champ de formulaire ordinaire — l'équivalent d'un `Form(...)` FastAPI.
    public mutating func champ(_ nom: String, _ valeur: String) {
        ajouter("--\(frontiere)\r\n")
        ajouter("Content-Disposition: form-data; name=\"\(nom)\"\r\n\r\n")
        ajouter("\(valeur)\r\n")
    }

    /// Un fichier. Le `nomFichier` ne sert QU'À l'affichage côté serveur : c'est
    /// le type MIME déclaré qui décide de tout le reste
    /// (`backend/fichiers/politique.py`), et un nom venu d'un appareil est une
    /// entrée non fiable.
    public mutating func fichier(
        _ nom: String, nomFichier: String, typeMime: String, octets: Data
    ) {
        ajouter("--\(frontiere)\r\n")
        ajouter(
            "Content-Disposition: form-data; name=\"\(nom)\"; "
            + "filename=\"\(echapper(nomFichier))\"\r\n"
        )
        ajouter("Content-Type: \(typeMime)\r\n\r\n")
        donnees.append(octets)
        ajouter("\r\n")
    }

    /// Le corps complet, frontière de clôture comprise. Sans les deux tirets
    /// finaux, le serveur attend indéfiniment une partie de plus.
    public func terminer() -> Data {
        var complet = donnees
        complet.append(Data("--\(frontiere)--\r\n".utf8))
        return complet
    }

    /// Un guillemet dans un nom de fichier fermerait l'attribut en plein milieu.
    private func echapper(_ texte: String) -> String {
        texte.replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private mutating func ajouter(_ texte: String) {
        donnees.append(Data(texte.utf8))
    }
}
