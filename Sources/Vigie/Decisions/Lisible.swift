// Les valeurs du domaine, écrites pour être lues à 3 h du matin sur un écran de
// 5,8 pouces. Aucune vue ici : uniquement la traduction d'un champ serveur en
// une phrase française.
//
// `☠` Le portage direct de `harness-rallonges.js` : `hPlafondLisible`,
// `hPlageLisible` et le titre variable d'une demande. Le titre CHANGE selon ce
// qui est demandé, et c'est délibéré — lâcher la main jusqu'à une heure donnée
// et relever un nombre d'équipes sans clic n'engagent pas la même chose. Un
// titre unique ferait valider l'un pour l'autre.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

public enum Lisible {

    /// Toutes les dates du contrat sont des entiers en millisecondes epoch.
    public static func instant(_ millisecondes: Int) -> Date {
        Date(timeIntervalSince1970: Double(millisecondes) / 1000)
    }

    // MARK: - Argent

    /// Un plafond en dollars. Deux décimales toujours : « 12 $ » et « 12,50 $ »
    /// côte à côte dans une file se comparent mal d'un coup d'œil.
    public static func montant(_ usd: Double) -> String {
        let chiffre = usd.formatted(
            .number.precision(.fractionLength(2)).locale(Locale(identifier: "fr_FR"))
        )
        return "\(chiffre) $"
    }

    // MARK: - Temps

    /// L'heure de dépôt : l'heure seule dans la journée, le jour dès qu'on en
    /// sort. Une décision posée avant-hier et affichée « 14:32 » se lirait comme
    /// une décision de tout à l'heure.
    public static func heure(_ millisecondes: Int) -> String {
        let date = instant(millisecondes)
        let calendrier = Calendar.current
        let heure = date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "fr_FR"))
        )
        if calendrier.isDateInToday(date) { return heure }
        if calendrier.isDateInYesterday(date) { return "hier \(heure)" }
        let jour = date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Locale(identifier: "fr_FR"))
        )
        return "\(jour) \(heure)"
    }

    // MARK: - Rallonges

    /// Ce qu'une demande de rallonge demande VRAIMENT, en titre.
    ///
    /// Les deux volets sont indépendants et au moins un est présent
    /// (migration 29). Trois libellés distincts, jamais un seul.
    public static func objetRallonge(_ demande: RallongeApi) -> String {
        if demande.porteUneFenetre {
            return demande.porteUnPlafond ? "Fenêtre d'autonomie et plafond" : "Fenêtre d'autonomie"
        }
        return "Rallonge du plafond d'autonomie"
    }

    /// La plage demandée. La FIN d'abord, le début seulement s'il n'est pas
    /// immédiat : ce qui se décide en accordant une fenêtre, c'est jusqu'à quand
    /// on lâche la main. Un début « maintenant » est le cas normal et n'apprend
    /// rien.
    public static func plage(debut: Int?, fin: Int?) -> String? {
        guard let fin else { return nil }
        guard let debut, instant(debut).timeIntervalSinceNow >= 120 else {
            return "jusqu'à \(heure(fin))"
        }
        return "de \(heure(debut)) à \(heure(fin))"
    }

    /// Combien de temps la fenêtre laisse la main, une fois accordée. C'est la
    /// vraie portée du geste, et elle ne se lit pas dans deux horodatages.
    public static func duree(debut: Int?, fin: Int?) -> String? {
        guard let fin else { return nil }
        let depart = debut.map(instant) ?? Date()
        let secondes = instant(fin).timeIntervalSince(depart)
        guard secondes > 0 else { return nil }
        let minutes = Int(secondes / 60)
        if minutes < 60 { return "\(minutes) min d'autonomie" }
        let heures = minutes / 60
        let reste = minutes % 60
        if reste == 0 { return "\(heures) h d'autonomie" }
        return "\(heures) h \(reste) min d'autonomie"
    }

    // MARK: - Mandats

    /// Le droit accordé, en toutes lettres. `☠` H-61 : c'est la seule phrase de
    /// la carte qui dit ce que l'équipe pourra FAIRE. « périmètre » est
    /// descriptif et n'a jamais rien verrouillé.
    public static func portee(_ acces: AccesMandatApi) -> String {
        acces.ouvreLEcriture
            ? "L'équipe modifiera les fichiers du projet et pourra commiter."
            : "L'équipe lit et rapporte. Elle ne modifie aucun fichier."
    }

    /// Le couple modèle / effort du mandat, quand il est fixé. `nil` ⇒ le défaut
    /// du dispatch s'applique, et on l'écrit plutôt que d'inventer un nom.
    public static func moteur(modele: String?, effort: String?) -> String {
        switch (modele, effort) {
        case (let modele?, let effort?): return "\(modele) · \(effort)"
        case (let modele?, nil): return modele
        case (nil, let effort?): return "défaut du dispatch · \(effort)"
        case (nil, nil): return "défaut du dispatch"
        }
    }
}
#endif
