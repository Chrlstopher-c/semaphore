// Les voix d'EchoHub Mobile. L'échelle est celle d'Apple ; ce qui est propre à
// l'app, c'est le CONTRASTE entre deux familles — une grotesque pour ce qui
// s'adresse à Chris, une chasse fixe pour ce qui vient d'une machine.
//
// Écart déclaré : l'interface de bureau utilise IBM Plex Sans/Mono,
// auto-hébergée. L'embarquer ici coûterait cinq fichiers de police dans l'IPA,
// ferait perdre Dynamic Type, et le skill iOS écarte les polices tierces pour
// du corps de texte. SF Pro + SF Mono donnent le MÊME contraste de nature sans
// un octet de police ; la continuité avec le bureau est portée par la palette
// et par le registre.
#if canImport(SwiftUI)
import SwiftUI

public enum Typo {
    // MARK: - Ce qui s'adresse à Chris (SF Pro)

    /// Titre d'écran. 26 et pas 34 : rien ne doit dominer la réponse du modèle.
    public static let titreEcran = Font.system(size: 26, weight: .semibold)
    public static let titreSection = Font.system(size: 18, weight: .semibold)
    /// **La réponse du modèle.** Le seul texte de l'app composé à cette taille
    /// dans cette encre — c'est ce qui en fait le sujet de chaque écran.
    public static let corps = Font.system(size: 17)
    public static let entete = Font.system(size: 17, weight: .semibold)
    public static let mention = Font.system(size: 15)
    public static let note = Font.system(size: 13)
    public static let legende = Font.system(size: 12)

    // MARK: - Ce qui vient d'une machine (SF Mono)

    /// Le registre `note` : raisonnement, commentaire de travail. Un
    /// raisonnement en chasse fixe se lit COMME DU TRAVAIL et non comme un
    /// propos — l'information est dans la forme avant d'être dans le mot.
    public static let pensee = Font.system(size: 14, design: .monospaced)
    /// Le registre `machine` : entrée et sortie brutes d'un outil, JSON,
    /// chemins de fichiers.
    public static let brut = Font.system(size: 12, design: .monospaced)

    // MARK: - Mesures

    /// Toute mesure : tokens, tokens/s, taille sur disque. Chiffres à chasse
    /// fixe — sans cela la largeur danse à chaque token généré, et un compteur
    /// qui tremble pendant une génération est insupportable.
    public static let mesure = Font.system(size: 13).monospacedDigit()
    public static let mesureFine = Font.system(size: 12).monospacedDigit()

    // MARK: - Interlignes de lecture

    /// L'interligne ajouté à la réponse du modèle et à la bulle de Chris.
    /// L'interligne par défaut d'iOS est réglé pour des libellés d'interface ;
    /// l'archétype de cette app est la page de lecture, et une réponse fait
    /// couramment trois écrans. +4 porte le corps 17 à ~26 de ligne (≈ 1,5) —
    /// le régime d'un livre, pas d'un réglage.
    ///
    /// Ces valeurs sont typographiques, HORS de la grille `Trame` : la règle
    /// « sous 4 pt il n'y a rien » gouverne les espacements de mise en page,
    /// pas la respiration interne d'un pavé de texte.
    public static let interligneReponse: CGFloat = 4
    /// Le registre `note` : long lui aussi (le `<think>` dépasse souvent la
    /// réponse), mais il se scanne plus qu'il ne se lit — un cran de moins.
    public static let interligneNote: CGFloat = 2
    /// Le registre `machine` : du brut, au rendu d'un terminal. Rien d'ajouté.
    public static let interligneMachine: CGFloat = 0
}

extension View {
    public func titreEcran() -> some View { font(Typo.titreEcran) }
    public func titreSection() -> some View { font(Typo.titreSection) }
    public func corps() -> some View { font(Typo.corps) }
    public func entete() -> some View { font(Typo.entete) }
    public func mention() -> some View { font(Typo.mention) }
    public func note() -> some View { font(Typo.note) }
    public func legende() -> some View { font(Typo.legende) }
    public func pensee() -> some View { font(Typo.pensee) }
    public func brut() -> some View { font(Typo.brut) }
    public func mesure() -> some View { font(Typo.mesure) }
    public func mesureFine() -> some View { font(Typo.mesureFine) }

    /// Tête de rubrique : capitales espacées, éteintes. La section s'annonce à
    /// voix basse — c'est le contenu qui parle.
    public func rubrique() -> some View {
        font(Typo.legende.weight(.semibold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Teinte.encreDouce)
    }
}
#endif
