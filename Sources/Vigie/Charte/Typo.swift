// Les trois voix de la charte : New York pour les titres, SF pour le corps,
// SF Mono pour toute mesure. Une heure, un montant, un identifiant = mono.
#if canImport(SwiftUI)
import SwiftUI

public enum Typo {
    // MARK: - Titres (serif — la voix du journal de quart)
    public static let grandTitre = Font.system(size: 28, weight: .semibold, design: .serif)
    public static let titreFeuille = Font.system(size: 20, weight: .semibold, design: .serif)

    // MARK: - Corps (SF)
    public static let phraseForte = Font.system(size: 15, weight: .semibold)
    public static let phrase = Font.system(size: 15, weight: .regular)
    public static let note = Font.system(size: 13, weight: .regular)
    public static let mention = Font.system(size: 11.5, weight: .regular)
    public static let rubriqueFonte = Font.system(size: 12, weight: .semibold)
    public static let insigneFonte = Font.system(size: 11, weight: .semibold)
    public static let libelleFonte = Font.system(size: 15, weight: .semibold)

    // MARK: - Mesures (mono)
    public static let chiffre = Font.system(size: 20, weight: .medium, design: .monospaced)
    public static let donnee = Font.system(size: 13, weight: .regular, design: .monospaced)
    public static let donneePetite = Font.system(size: 11.5, weight: .regular, design: .monospaced)
    public static let donneeMinuscule = Font.system(size: 10, weight: .regular, design: .monospaced)
    public static let fonteTerminal = Font.system(size: 11.5, weight: .regular, design: .monospaced)
}

extension View {
    public func grandTitre() -> some View { font(Typo.grandTitre) }
    public func titreFeuille() -> some View { font(Typo.titreFeuille) }

    public func phraseForte() -> some View { font(Typo.phraseForte) }
    public func phrase() -> some View { font(Typo.phrase) }
    public func note() -> some View { font(Typo.note) }
    public func mention() -> some View { font(Typo.mention) }

    /// Tête de section : majuscules espacées, ternies. La section s'annonce à
    /// voix basse — c'est le contenu qui parle.
    public func rubrique() -> some View {
        font(Typo.rubriqueFonte)
            .kerning(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Teinte.encreTernie)
    }

    public func insigne() -> some View { font(Typo.insigneFonte).kerning(0.3) }
    public func libelle() -> some View { font(Typo.libelleFonte) }

    public func chiffre() -> some View { font(Typo.chiffre) }
    public func donnee() -> some View { font(Typo.donnee) }
    public func donneePetite() -> some View { font(Typo.donneePetite) }
    public func donneeMinuscule() -> some View { font(Typo.donneeMinuscule) }
    public func texteTerminal() -> some View { font(Typo.fonteTerminal) }
}
#endif
