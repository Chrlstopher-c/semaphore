import Foundation

/// L'encodage et le décodage JSON du contrat EchoHub, décidés en UN seul
/// endroit.
///
/// Deux règles, toutes deux imposées par le serveur et non par un goût :
///
/// 1. **`snake_case`** — les modèles pydantic d'EchoHub v2 exposent
///    `conversation_id`, `cree_le`, `modele_id`. Convertir ici évite d'écrire
///    des `CodingKeys` dans chaque DTO, donc d'oublier d'en écrire un.
/// 2. **Les dates ne sont pas `.iso8601`** — `JSONDecoder.DateDecodingStrategy
///    .iso8601` REFUSE les fractions de seconde, que pydantic écrit
///    systématiquement (`2026-08-26T06:22:31.123456`). Un `.iso8601` naïf fait
///    échouer le décodage de TOUTE la liste des conversations sur un champ que
///    personne ne regarde. D'où la liste de formats ci-dessous.
public enum CodageJSON {
    public static func decodeur() -> JSONDecoder {
        let decodeur = JSONDecoder()
        decodeur.keyDecodingStrategy = .convertFromSnakeCase
        decodeur.dateDecodingStrategy = .custom { conteneur in
            let texte = try conteneur.singleValueContainer().decode(String.self)
            guard let date = dateDepuis(texte) else {
                throw DecodingError.dataCorruptedError(
                    in: try conteneur.singleValueContainer(),
                    debugDescription: "Date non reconnue : « \(texte) »"
                )
            }
            return date
        }
        return decodeur
    }

    public static func encodeur() -> JSONEncoder {
        let encodeur = JSONEncoder()
        encodeur.keyEncodingStrategy = .convertToSnakeCase
        encodeur.dateEncodingStrategy = .iso8601
        return encodeur
    }

    /// Les formes réellement émises par pydantic, de la plus fréquente à la plus
    /// rare : avec fuseau et fraction, avec fuseau seul, naïve avec fraction,
    /// naïve seule. Aucune n'est là « au cas où » — ce sont les quatre sorties
    /// possibles de `datetime.isoformat()` selon que le `datetime` porte un
    /// fuseau et des microsecondes.
    static func dateDepuis(_ texte: String) -> Date? {
        // Un seul appel par formateur : le `where` d'une boucle est évalué AVANT
        // le corps, donc la forme précédente analysait deux fois chaque date qui
        // correspondait — soit deux `DateFormatter` par date sur toute une liste
        // de conversations.
        for formateur in formateurs {
            if let date = formateur.date(from: texte) { return date }
        }
        return nil
    }

    private static let formateurs: [DateFormatter] = [
        formateur("yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"),
        formateur("yyyy-MM-dd'T'HH:mm:ssXXXXX"),
        formateur("yyyy-MM-dd'T'HH:mm:ss.SSSSSS"),
        formateur("yyyy-MM-dd'T'HH:mm:ss"),
    ]

    private static func formateur(_ gabarit: String) -> DateFormatter {
        let formateur = DateFormatter()
        formateur.locale = Locale(identifier: "en_US_POSIX")
        formateur.timeZone = TimeZone(secondsFromGMT: 0)
        formateur.dateFormat = gabarit
        return formateur
    }
}
