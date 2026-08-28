import Foundation

/// La géométrie d'un fil qu'on est en train de lire, réduite à ce qui décide
/// de deux choses : recoller au bas quand un tour arrive, et proposer d'y
/// sauter quand on en est loin.
public struct EtatDefilement: Equatable, Sendable {
    /// Hauteur restant sous le bas de l'écran. Zéro = on est collé au bas.
    public var distanceAuBas: CGFloat
    /// Hauteur de la fenêtre de lecture.
    public var hauteurVisible: CGFloat
    /// Hauteur de tout le fil, tours empilés.
    public var hauteurTotale: CGFloat
    /// Nombre de tours affichés.
    public var messages: Int

    public init(
        distanceAuBas: CGFloat = 0,
        hauteurVisible: CGFloat = 0,
        hauteurTotale: CGFloat = 0,
        messages: Int = 0
    ) {
        self.distanceAuBas = distanceAuBas
        self.hauteurVisible = hauteurVisible
        self.hauteurTotale = hauteurTotale
        self.messages = messages
    }

    /// Au-delà, on considère que Chris est resté en bas : un tour qui arrive
    /// peut recoller sans lui voler sa lecture.
    public static let toleranceColle: CGFloat = 60
    /// Le nombre de messages sous le pli à partir duquel remonter le fil au
    /// pouce devient une corvée.
    public static let messagesAvantFleche = 5

    public var colleAuBas: Bool {
        distanceAuBas < Self.toleranceColle
    }

    /// `☠` Un tour d'orchestrateur va d'une ligne à trois écrans : un seuil en
    /// points fixes afficherait la flèche au bout d'un seul long message dans un
    /// fil, et jamais dans un autre. La hauteur moyenne d'un tour DE CE FIL est
    /// la seule mesure qui suive ce que Chris voit — elle s'ajuste toute seule
    /// selon qu'il lit des accusés de réception ou des rapports.
    ///
    /// Le plancher d'une hauteur d'écran est là pour le cas inverse : dans un
    /// fil de messages minuscules, cinq d'entre eux tiennent sous le pouce et ne
    /// justifient aucune flèche.
    public var loinDuBas: Bool {
        guard messages > 0, hauteurTotale > 0, hauteurVisible > 0 else { return false }
        let moyenne = hauteurTotale / CGFloat(messages)
        return distanceAuBas >= hauteurVisible
            && distanceAuBas >= moyenne * CGFloat(Self.messagesAvantFleche)
    }
}
