// Les voix d'EchoHub Mobile — désormais celles du socle `Systeme` : serif
// éditorial pour les titres, sans système pour le courant, chasse fixe pour la
// machine, toutes bâties sur des text styles Dynamic Type. Ce qui reste propre
// à l'app : les interlignes de lecture, valeurs typographiques hors grille.
//
// Le CONTRASTE entre deux natures demeure — ce qui s'adresse à Chris en
// proportionnel, ce qui vient d'une machine en chasse fixe. L'information est
// dans la forme avant d'être dans le mot.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Typo {
    // MARK: - Ce qui s'adresse à Chris — voix du socle, Dynamic Type

    /// Titre d'écran. Serif éditorial : rien ne doit dominer la réponse du
    /// modèle, et le serif titre sans crier.
    public static let titreEcran = Voix.titreEcran
    public static let titreSection = Voix.titreSection
    /// **La réponse du modèle.** Le seul texte de l'app composé à cette voix
    /// dans cette encre — c'est ce qui en fait le sujet de chaque écran.
    public static let corps = Voix.corps
    public static let entete = Voix.entete
    public static let mention = Voix.mention
    public static let note = Voix.note
    public static let legende = Voix.legende

    // MARK: - Ce qui vient d'une machine — chasse fixe du socle

    /// Le registre `note` : raisonnement, commentaire de travail. Un
    /// raisonnement en chasse fixe se lit COMME DU TRAVAIL et non comme un
    /// propos.
    public static let pensee = Voix.brut
    /// Le registre `machine` : entrée et sortie brutes d'un outil, JSON,
    /// chemins de fichiers.
    public static let brut = Voix.brut

    // MARK: - Mesures

    /// Toute mesure : tokens, tokens/s, taille sur disque. Chiffres à chasse
    /// fixe — sans cela la largeur danse à chaque token généré, et un compteur
    /// qui tremble pendant une génération est insupportable.
    public static let mesure = Voix.mesure
    public static let mesureFine = Voix.mesure

    // MARK: - Interlignes de lecture — propres à EchoHub, hors grille

    /// L'interligne ajouté à la réponse du modèle et à la bulle de Chris.
    /// L'interligne par défaut d'iOS est réglé pour des libellés d'interface ;
    /// l'archétype de cette app est la page de lecture, et une réponse fait
    /// couramment trois écrans. Le régime d'un livre, pas d'un réglage.
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
