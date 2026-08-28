// Conversion des instants du contrat (entiers epoch ms) vers ce que l'écran
// affiche. Local au domaine Fil : `Decisions/Lisible.swift` fait la même chose
// pour son domaine, et les deux ne se mutualisent pas — deux formatages qui
// changeraient pour des raisons différentes n'ont rien à partager.
#if canImport(SwiftUI)
import Foundation

/// Millisecondes epoch du contrat → `Date`.
func instantFil(_ millisecondes: Int) -> Date {
    Date(timeIntervalSince1970: Double(millisecondes) / 1000)
}

/// L'heure seule, « HH:MM:SS » — ce que porte chaque ligne du fil segmenté.
/// `@MainActor` : `DateFormatter` n'est pas `Sendable`, et cette fonction n'est
/// jamais appelée hors d'un corps de vue.
@MainActor func heureFil(_ millisecondes: Int) -> String {
    let date = instantFil(millisecondes)
    return Horodatage.formateur.string(from: date)
}

private enum Horodatage {
    /// `DateFormatter` n'est pas `Sendable` ; au repos sur le MainActor comme
    /// tout ce fichier, qui ne vit que dans des vues.
    @MainActor static let formateur: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()
}
#endif
