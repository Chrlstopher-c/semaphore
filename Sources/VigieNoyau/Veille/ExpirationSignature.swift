import Foundation

/// Lit la date d'expiration du profil de provisionnement embarqué.
///
/// `☠` En free provisioning, la signature vaut **sept jours**. Passé ce délai
/// l'application ne se lance plus du tout : pas d'avertissement, pas de message,
/// elle refuse de s'ouvrir. Toute la chaîne d'alerte meurt avec elle, et le
/// silence qui suit ressemble exactement à un parc calme. Prévenir la veille est
/// donc une fonction de sûreté, pas un confort.
///
/// `embedded.mobileprovision` est un conteneur CMS (DER) qui EMBALLE un plist
/// XML. On ne déballe pas le CMS — on découpe la fenêtre XML au motif et on lit
/// la clé. Aucune dépendance, aucune API système, donc éprouvable sur Arch.
public enum ExpirationSignature {

    public static let nomFichier = "embedded"
    public static let extensionFichier = "mobileprovision"

    /// La date d'expiration, ou `nil` si le fichier est absent ou illisible.
    /// Un profil illisible n'est pas une panne : l'application tourne quand même,
    /// on perd seulement l'avertissement — et l'écran du canal le dit.
    public static func lire(_ donnees: Data) -> Date? {
        guard let texte = fenetreXML(donnees) else { return nil }
        guard let brut = valeurDate(cle: "ExpirationDate", dans: texte) else { return nil }
        return dateISO(brut)
    }

    /// Découpe la portion XML du conteneur. `String(decoding:)` sur l'ensemble
    /// suffit : les octets DER hors plage UTF-8 deviennent des caractères de
    /// remplacement, ce qui ne gêne pas une recherche de motif ASCII.
    private static func fenetreXML(_ donnees: Data) -> String? {
        let entier = String(decoding: donnees, as: UTF8.self)
        guard let debut = entier.range(of: "<?xml"),
              let fin = entier.range(of: "</plist>", options: .backwards) else { return nil }
        return String(entier[debut.lowerBound..<fin.upperBound])
    }

    /// `<key>NOM</key>` suivi de `<date>…</date>`. La recherche part de la clé et
    /// non du début : un plist en contient plusieurs et la première balise
    /// `<date>` du fichier n'est pas forcément la bonne.
    private static func valeurDate(cle: String, dans texte: String) -> String? {
        guard let apresCle = texte.range(of: "<key>\(cle)</key>") else { return nil }
        let suite = texte[apresCle.upperBound...]
        guard let ouvrante = suite.range(of: "<date>"),
              let fermante = suite.range(of: "</date>") ,
              ouvrante.upperBound <= fermante.lowerBound else { return nil }
        return String(suite[ouvrante.upperBound..<fermante.lowerBound])
    }

    /// `2026-08-24T09:31:12Z` → `Date`. Découpage à la main : `ISO8601DateFormatter`
    /// n'est pas `Sendable` et cette lecture peut partir d'un réveil de fond.
    static func dateISO(_ brut: String) -> Date? {
        let chiffres = brut.split(whereSeparator: { !$0.isNumber }).map(String.init)
        guard chiffres.count >= 6 else { return nil }
        let nombres = chiffres.prefix(6).compactMap(Int.init)
        guard nombres.count == 6 else { return nil }
        var elements = DateComponents()
        elements.year = nombres[0]
        elements.month = nombres[1]
        elements.day = nombres[2]
        elements.hour = nombres[3]
        elements.minute = nombres[4]
        elements.second = nombres[5]
        var calendrier = Calendar(identifier: .gregorian)
        // Le plist d'Apple date en UTC (suffixe `Z`). Interpréter avec le fuseau
        // de l'appareil décalerait l'alarme de plusieurs heures.
        calendrier.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendrier.date(from: elements)
    }

    /// L'alerte à poser la veille de l'expiration. `nil` quand l'échéance est
    /// déjà passée (l'application ne se lancerait plus) ou trop proche pour
    /// qu'un préavis d'un jour ait encore un sens.
    public static func projet(
        expiration: Date,
        maintenant: Date = Date()
    ) -> ProjetNotification? {
        let delai = expiration.timeIntervalSince(maintenant) - 86_400
        guard delai > 0 else { return nil }
        return ProjetNotification(
            identifiant: "signature.expiration",
            genre: .signature,
            titre: "Signature de Vigie expirée demain",
            sousTitre: "resigner l'IPA avant la coupure",
            corps: "Passé l'échéance, l'application ne se lancera plus et la "
                + "chaîne d'alerte s'arrêtera sans rien dire.",
            fil: "signature",
            donnees: [ProjetNotification.Cle.genre: GenreAlerte.signature.rawValue],
            insistance: .active,
            delai: delai
        )
    }
}
