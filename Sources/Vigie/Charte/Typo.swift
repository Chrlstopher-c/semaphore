// Les voix de la charte, adossées au socle `Systeme` : serif éditorial pour
// les titres, sans système pour le courant, mono pour toute mesure — le tout en
// Dynamic Type. Les noms historiques restent : les composants écrivent
// `Typo.phrase` sans changement.
//
// Les voix MONO fines (chiffre, donnee…) sont propres à Vigie — pas
// d'équivalent socle — mais réécrites sur des text styles système, cohérentes
// avec `Voix.mesure`/`Voix.brut`. Plus aucune taille en dur.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Typo {
    // MARK: - Titres (serif — la voix du journal de quart) — socle

    public static let grandTitre = Voix.titreEcran
    public static let titreFeuille = Voix.titreSection

    // MARK: - Corps (SF) — socle

    public static let phraseForte = Voix.entete
    public static let phrase = Voix.corps
    public static let note = Voix.note
    public static let mention = Voix.mention
    public static let rubriqueFonte = Voix.legende
    public static let insigneFonte = Voix.legende
    public static let libelleFonte = Voix.entete

    // MARK: - Mesures (mono) — propres à Vigie, en Dynamic Type

    /// Le grand compteur d'une carte. Chiffres à chasse fixe pour que la
    /// largeur ne tremble pas.
    public static let chiffre = Font.system(.title3, design: .monospaced, weight: .medium)
        .monospacedDigit()
    /// La donnée courante : horodatage, identifiant, mesure en rangée.
    public static let donnee = Font.system(.footnote, design: .monospaced)
    public static let donneePetite = Font.system(.caption, design: .monospaced)
    public static let donneeMinuscule = Font.system(.caption2, design: .monospaced)
    /// La sortie de terminal — même dessin que `Voix.brut`, un cran plus petit.
    public static let fonteTerminal = Font.system(.caption, design: .monospaced)
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
