import Foundation

/// Le rattrapage de dérive d'horloge — la pièce qui décide si une écoute tient
/// une heure ou décroche au bout de vingt minutes.
///
/// Le problème, en clair : le convertisseur du PC et celui de l'iPhone disent
/// tous les deux « 48 000 Hz » et se trompent tous les deux, de quelques dizaines
/// de parties par million, pas du même côté. À 50 ppm d'écart — ordinaire pour
/// deux quartz grand public — le tampon gagne ou perd 180 ms par heure. Il finit
/// donc soit vide (hoquets continus), soit gonflé (la latence enfle sans jamais
/// redescendre). Aucune des deux ne se rattrape en jetant des paquets : il faut
/// LIRE un peu plus vite ou un peu moins vite, en permanence, sans que ça
/// s'entende.
///
/// `☠` Le correcteur est pur — aucune horloge, aucun état audio. Il prend le
/// remplissage observé du tampon et rend un facteur de débit. C'est ce qui le
/// rend éprouvable sous `swift test`, où il n'y a ni carte son ni appareil.
public struct CorrectionDerive: Sendable, Equatable {

    /// Le remplissage visé, fixé par `PROTOCOLE.md`.
    public static let cibleMs: Double = 100

    /// L'écart maximal toléré sur le débit de lecture : ±0,3 %. C'est le
    /// plafond du protocole, et c'est aussi le seuil au-delà duquel un
    /// rééchantillonnage continu s'entend sur une voix ou un piano.
    public static let ecartMaximal: Double = 0.003

    /// Sous cet écart au but, on ne corrige pas. Sans zone morte, le correcteur
    /// pourchasse le bruit de mesure et module le débit en permanence pour rien.
    public static let zoneMorteMs: Double = 4

    /// L'écart de remplissage qui sature la correction. À 50 ms de dérive, on
    /// donne les 0,3 % complets ; en deçà, proportionnellement moins.
    public static let ecartSaturantMs: Double = 50

    /// Part du but reprise à chaque observation. Le correcteur met une centaine
    /// d'observations à rejoindre sa consigne — quelques secondes au rythme des
    /// blocs de rendu.
    ///
    /// `☠` Ce lissage n'est pas du confort : un facteur qui saute d'un bloc à
    /// l'autre produit un craquement à chaque marche. La correction doit être
    /// inaudible, donc lente.
    public static let lissage: Double = 0.02

    /// Le facteur de débit courant. 1,0 = on lit à la vitesse nominale ; 1,003 =
    /// on consomme 0,3 % plus vite, donc le tampon se vide.
    public private(set) var facteur: Double = 1

    public init() {}

    /// Observe le remplissage réel et avance le facteur d'un pas vers sa
    /// consigne. À appeler une fois par bloc de rendu ; rend le facteur à
    /// appliquer tout de suite.
    @discardableResult
    public mutating func observer(remplissageMs: Double) -> Double {
        let vise = Self.facteurVise(remplissageMs: remplissageMs)
        facteur += (vise - facteur) * Self.lissage
        return facteur
    }

    /// Le facteur que le correcteur cherche à atteindre pour ce remplissage —
    /// la consigne, avant lissage. Public parce que c'est lui qui se lit dans un
    /// test : le facteur courant, lui, dépend de tout l'historique.
    public static func facteurVise(remplissageMs: Double) -> Double {
        let ecart = remplissageMs - cibleMs
        guard abs(ecart) > zoneMorteMs else { return 1 }
        // Le signe : trop plein → on lit plus vite pour redescendre vers la
        // cible ; trop vide → on ralentit pour laisser le tampon se refaire.
        let part = ecart / ecartSaturantMs
        let borne = min(max(part, -1), 1)
        return 1 + borne * ecartMaximal
    }

    /// Remet le débit au nominal. Après un réamorçage, l'historique de dérive ne
    /// vaut plus rien — le tampon vient d'être rempli de force à la cible.
    public mutating func reinitialiser() {
        facteur = 1
    }
}
