import Foundation

/// Construit un corps `multipart/form-data` pour `POST /api/blobs` (champ
/// `file`).
///
/// `☠` Écrit à la main, et c'est voulu : ce projet s'interdit toute dépendance
/// externe, et `URLSession` n'en fabrique aucun. Le format ne pardonne pas —
/// une terminaison en `\n` au lieu de `\r\n` fait rendre un `400`/`422` par un
/// serveur qui ne dira jamais pourquoi. D'où un type pur, éprouvé par
/// `swift test`. (Homonyme de celui d'EchoHub, module distinct, sans collision.)
public struct CorpsMultipart {
    /// La frontière. Aléatoire par défaut : elle ne doit apparaître dans aucune
    /// partie, et un octet de photo peut contenir n'importe quoi.
    public let frontiere: String
    private var donnees = Data()

    public init(frontiere: String = "saily-" + UUID().uuidString) {
        self.frontiere = frontiere
    }

    public var typeContenu: String { "multipart/form-data; boundary=\(frontiere)" }

    /// Un fichier. Le `nomFichier` ne sert QU'À l'affichage/l'extension côté
    /// serveur (le blob est nommé par hash de contenu), et un nom venu d'un
    /// appareil est une entrée non fiable — d'où l'échappement.
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

    private func echapper(_ texte: String) -> String {
        texte.replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private mutating func ajouter(_ texte: String) {
        donnees.append(Data(texte.utf8))
    }
}
