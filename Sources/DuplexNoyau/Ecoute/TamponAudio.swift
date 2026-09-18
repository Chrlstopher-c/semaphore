import Foundation
import Synchronization

/// Le tampon circulaire entre le réseau et la carte son. Un seul producteur (la
/// réception UDP), un seul consommateur (le rappel de rendu), et RIEN entre les
/// deux — ni verrou, ni allocation, ni appel système.
///
/// `☠` C'est la raison des atomiques plutôt que d'un `NSLock`. Le rappel de
/// rendu d'`AVAudioEngine` tourne sur un fil temps réel : s'il se bloque ne
/// serait-ce qu'une milliseconde sur un verrou tenu par le réseau, le système
/// coupe le bloc et Chris entend un trou. Un anneau à deux indices atomiques n'a
/// pas ce problème — chaque côté n'écrit que son propre indice.
///
/// Les indices sont MONOTONES, jamais repliés : à 48 kHz, un `Int` 64 bits tient
/// six millions d'années. Le repli ne se fait qu'à l'accès au stockage.
public final class TamponAudio: @unchecked Sendable {

    /// Le tampon physique tient bien plus que la cible : la cible est un point
    /// d'équilibre, pas un plafond. Une rafale réseau doit pouvoir entrer sans
    /// rien perdre, quitte à ce que la correction de dérive la résorbe ensuite.
    public static let capaciteParDefautMs: Double = 600

    public let capaciteTrames: Int
    /// Le remplissage à atteindre avant que le son démarre — la reprise du
    /// protocole : « le tampon se remplit jusqu'à la cible avant que le son
    /// démarre ».
    public let seuilAmorcageTrames: Int

    private let stockage: UnsafeMutableBufferPointer<Int16>
    private let teteEcriture = Atomic<Int>(0)
    private let teteLecture = Atomic<Int>(0)
    private let amorcage = Atomic<Bool>(false)
    private let compteDepassements = Atomic<Int>(0)
    private let compteFamines = Atomic<Int>(0)

    public init(
        capaciteMs: Double = TamponAudio.capaciteParDefautMs,
        cibleMs: Double = CorrectionDerive.cibleMs
    ) {
        let parMs = EnTetePaquet.frequence / 1000
        capaciteTrames = max(Int(capaciteMs * parMs), EnTetePaquet.tramesParPaquet * 4)
        seuilAmorcageTrames = min(Int(cibleMs * parMs), capaciteTrames / 2)
        stockage = UnsafeMutableBufferPointer<Int16>.allocate(
            capacity: capaciteTrames * EnTetePaquet.canaux
        )
        stockage.initialize(repeating: 0)
    }

    deinit {
        stockage.deallocate()
    }

    // MARK: - Ce que les deux côtés lisent

    /// Les trames prêtes à être lues.
    public var tramesDisponibles: Int {
        teteEcriture.load(ordering: .acquiring) - teteLecture.load(ordering: .acquiring)
    }

    /// Le remplissage en millisecondes — la mesure que `CorrectionDerive` lit.
    public var remplissageMs: Double {
        Double(tramesDisponibles) / EnTetePaquet.frequence * 1000
    }

    /// Vrai quand le tampon a atteint la cible au moins une fois et que le son
    /// coule. Faux au départ et après chaque famine.
    public var amorce: Bool { amorcage.load(ordering: .acquiring) }

    /// Nombre de fois où des trames ont été jetées faute de place.
    public var depassements: Int { compteDepassements.load(ordering: .relaxed) }
    /// Nombre de fois où le rendu a manqué de matière et a joué du silence.
    public var famines: Int { compteFamines.load(ordering: .relaxed) }

    // MARK: - Côté producteur — la réception réseau

    /// Écrit des échantillons entrelacés. Rend le nombre de TRAMES écrites ;
    /// moins que demandé signifie que le tampon a débordé.
    ///
    /// `☠` En cas de débordement on jette les trames les PLUS RÉCENTES et on ne
    /// bouge pas la tête de lecture. Jeter les anciennes à la place ferait
    /// sauter le son d'un bloc sans prévenir le lecteur ; ici, la correction de
    /// dérive voit simplement un tampon plein et accélère.
    @discardableResult
    public func ecrire(_ echantillons: [Int16]) -> Int {
        let trames = echantillons.count / EnTetePaquet.canaux
        guard trames > 0 else { return 0 }
        let place = capaciteTrames - tramesDisponibles
        let retenues = min(trames, place)
        if retenues < trames { compteDepassements.add(1, ordering: .relaxed) }
        guard retenues > 0 else { return 0 }
        let debut = teteEcriture.load(ordering: .relaxed)
        for trame in 0..<retenues {
            let source = trame * EnTetePaquet.canaux
            let cible = position(debut + trame)
            stockage[cible] = echantillons[source]
            stockage[cible + 1] = echantillons[source + 1]
        }
        teteEcriture.store(debut + retenues, ordering: .releasing)
        return retenues
    }

    /// Comble un trou de séquence par la durée exacte manquante, en silence.
    /// Le protocole l'impose : on ne redemande jamais un paquet perdu.
    @discardableResult
    public func ecrireSilence(trames: Int) -> Int {
        guard trames > 0 else { return 0 }
        let retenues = min(trames, capaciteTrames - tramesDisponibles)
        if retenues < trames { compteDepassements.add(1, ordering: .relaxed) }
        guard retenues > 0 else { return 0 }
        let debut = teteEcriture.load(ordering: .relaxed)
        for trame in 0..<retenues {
            let cible = position(debut + trame)
            stockage[cible] = 0
            stockage[cible + 1] = 0
        }
        teteEcriture.store(debut + retenues, ordering: .releasing)
        return retenues
    }

    // MARK: - Côté consommateur — le rappel de rendu

    /// Remplit `destination` (entrelacée, `trames` trames) au débit `facteur`.
    /// Rend le nombre de trames réellement sonores ; le reste est du silence.
    ///
    /// Zéro allocation, zéro verrou : tout ce qui suit est appelable depuis le
    /// fil temps réel.
    @discardableResult
    public func lire(
        dans destination: UnsafeMutablePointer<Int16>,
        trames: Int,
        facteur: Double,
        lecteur: inout LectureEtiree
    ) -> Int {
        guard trames > 0 else { return 0 }
        guard pretAServir(trames: trames, facteur: facteur, lecteur: lecteur) else {
            destination.update(repeating: 0, count: trames * EnTetePaquet.canaux)
            return 0
        }
        let tete = teteLecture.load(ordering: .relaxed)
        let consommees = lecteur.produire(
            trames: trames, facteur: facteur,
            source: { decalage in
                let index = self.position(tete + decalage)
                return (self.stockage[index], self.stockage[index + 1])
            },
            sortie: { index, gauche, droite in
                destination[index * EnTetePaquet.canaux] = gauche
                destination[index * EnTetePaquet.canaux + 1] = droite
            }
        )
        teteLecture.store(tete + consommees, ordering: .releasing)
        return trames
    }

    /// L'amorçage et la famine, en un seul endroit : tant que le tampon n'a pas
    /// atteint la cible, on joue du silence ; s'il se vide en cours de route, on
    /// repasse en amorçage plutôt que de hoqueter trame par trame.
    private func pretAServir(trames: Int, facteur: Double, lecteur: LectureEtiree) -> Bool {
        let besoin = lecteur.besoinEnTrames(trames, facteur: facteur)
        if !amorce {
            guard tramesDisponibles >= max(seuilAmorcageTrames, besoin) else { return false }
            amorcage.store(true, ordering: .releasing)
            return true
        }
        guard tramesDisponibles >= besoin else {
            compteFamines.add(1, ordering: .relaxed)
            amorcage.store(false, ordering: .releasing)
            return false
        }
        return true
    }

    // MARK: - Reprise

    /// Jette tout et repasse en amorçage. Appelé sur une rupture de flux ou à
    /// l'arrêt de l'écoute : garder un tampon périmé rejouerait de vieux
    /// échantillons avant les nouveaux.
    public func vider() {
        teteLecture.store(teteEcriture.load(ordering: .acquiring), ordering: .releasing)
        amorcage.store(false, ordering: .releasing)
    }

    private func position(_ trame: Int) -> Int {
        (trame % capaciteTrames) * EnTetePaquet.canaux
    }
}
