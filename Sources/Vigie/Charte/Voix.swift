// La typographie Echo Agency : Manrope (titres, interface) et JetBrains Mono (étiquettes, chiffres), embarquées.
// Écart déclaré au skill ios-design : le corps long du fil reste en police système (lecture, Dynamic Type).
#if canImport(SwiftUI)
import CoreText
import SwiftUI
import VigieNoyau

enum Voix {
    /// `UIAppFonts` ne voit pas `Bundle.module` : enregistrement explicite, une fois, au démarrage de la coquille.
    static let enregistrer: Void = {
        for nom in ["Manrope", "JetBrainsMono"] {
            guard let url = Bundle.module.url(forResource: nom, withExtension: "ttf", subdirectory: "Polices") else {
                Trace.erreur("charte", "police \(nom) absente du paquet")
                continue
            }
            var erreur: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &erreur) {
                Trace.erreur("charte", "police \(nom) non enregistrée")
            }
        }
    }()

    static func manrope(_ taille: CGFloat, _ graisse: Font.Weight = .regular, relative style: Font.TextStyle = .body) -> Font {
        .custom("Manrope", size: taille, relativeTo: style).weight(graisse)
    }

    static func mono(_ taille: CGFloat, _ graisse: Font.Weight = .regular) -> Font {
        .custom("JetBrains Mono", size: taille, relativeTo: .caption).weight(graisse)
    }

    // L'échelle de l'app : quatre tailles de texte courant, plus le titre d'écran.
    static let titreEcran = manrope(30, .heavy, relative: .largeTitle)
    static let titre = manrope(22, .heavy, relative: .title2)
    static let entete = manrope(17, .bold, relative: .headline)
    static let courant = manrope(15, .medium, relative: .subheadline)
    static let petit = manrope(13, .medium, relative: .footnote)
    static let etiquette = mono(11, .medium)
    static let chiffre = mono(12, .medium)
    static let lecture = Font.system(.callout) // corps long du fil
}
#endif
