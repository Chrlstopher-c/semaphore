import XCTest
@testable import DuplexNoyau

/// Le tampon circulaire, côté comportement : amorçage, trou comblé, famine,
/// débordement. Ces cas ne se constatent pas à l'oreille sans y passer l'après-midi.
final class TamponAudioTests: XCTestCase {

    private func trames(_ nombre: Int, valeur: Int16 = 1_000) -> [Int16] {
        [Int16](repeating: valeur, count: nombre * EnTetePaquet.canaux)
    }

    /// Un rendu, comme le ferait `AVAudioSourceNode` : rend ce qui est sorti.
    private func rendre(
        _ tampon: TamponAudio, trames nombre: Int, facteur: Double = 1,
        lecteur: inout LectureEtiree
    ) -> (sonores: Int, sortie: [Int16]) {
        var sortie = [Int16](repeating: 0, count: nombre * EnTetePaquet.canaux)
        let sonores = sortie.withUnsafeMutableBufferPointer {
            tampon.lire(
                dans: $0.baseAddress!, trames: nombre, facteur: facteur, lecteur: &lecteur
            )
        }
        return (sonores, sortie)
    }

    // MARK: - Amorçage

    /// `☠` La reprise du protocole : « le tampon se remplit jusqu'à la cible
    /// avant que le son démarre ». Sans ce sas, la lecture part sur trois
    /// paquets et hoquette pendant les dix premières secondes.
    func testLeSonNeDemarrePasAvantLaCible() {
        let tampon = TamponAudio()
        var lecteur = LectureEtiree()
        tampon.ecrire(trames(tampon.seuilAmorcageTrames - 10))
        let avant = rendre(tampon, trames: 256, lecteur: &lecteur)
        XCTAssertEqual(avant.sonores, 0)
        XCTAssertTrue(avant.sortie.allSatisfy { $0 == 0 }, "avant amorçage : du silence")
        XCTAssertFalse(tampon.amorce)

        tampon.ecrire(trames(64))
        let apres = rendre(tampon, trames: 256, lecteur: &lecteur)
        XCTAssertEqual(apres.sonores, 256)
        XCTAssertTrue(tampon.amorce)
        XCTAssertTrue(apres.sortie.allSatisfy { $0 == 1_000 })
    }

    func testLeSeuilDAmorcageVautLaCibleDuProtocole() {
        let tampon = TamponAudio()
        let ms = Double(tampon.seuilAmorcageTrames) / EnTetePaquet.frequence * 1000
        XCTAssertEqual(ms, CorrectionDerive.cibleMs, accuracy: 0.05)
    }

    // MARK: - Famine

    /// Quand la matière manque, on repasse en amorçage plutôt que de hoqueter
    /// trame par trame : un silence franc vaut mieux qu'un grésillement.
    func testUneFamineRepasseEnAmorcage() {
        let tampon = TamponAudio()
        var lecteur = LectureEtiree()
        tampon.ecrire(trames(tampon.seuilAmorcageTrames + 100))
        _ = rendre(tampon, trames: 256, lecteur: &lecteur)
        XCTAssertTrue(tampon.amorce)

        // On vide en lisant bien plus que ce qui reste.
        while tampon.tramesDisponibles > 512 {
            _ = rendre(tampon, trames: 512, lecteur: &lecteur)
        }
        let creuse = rendre(tampon, trames: 2_048, lecteur: &lecteur)
        XCTAssertEqual(creuse.sonores, 0)
        XCTAssertFalse(tampon.amorce)
        XCTAssertEqual(tampon.famines, 1)
        XCTAssertTrue(creuse.sortie.allSatisfy { $0 == 0 })
    }

    // MARK: - Trous et débordements

    func testLeSilenceComblEExactementLaDureeDemandee() {
        let tampon = TamponAudio()
        XCTAssertEqual(tampon.ecrireSilence(trames: 720), 720)
        XCTAssertEqual(tampon.tramesDisponibles, 720)
        XCTAssertEqual(tampon.remplissageMs, 15, accuracy: 0.001)
    }

    /// `☠` Au débordement on jette les trames les plus RÉCENTES et on ne touche
    /// pas la tête de lecture : jeter les anciennes ferait sauter le son sans
    /// que personne ne le sache.
    func testUnDebordementJetteEtSeCompteSansBougerLaLecture() {
        let tampon = TamponAudio()
        let ecrites = tampon.ecrire(trames(tampon.capaciteTrames + 5_000))
        XCTAssertEqual(ecrites, tampon.capaciteTrames)
        XCTAssertEqual(tampon.depassements, 1)
        XCTAssertEqual(tampon.tramesDisponibles, tampon.capaciteTrames)
    }

    /// `☠` L'anneau se replie plusieurs fois, et ce qui en SORT doit être
    /// exactement ce qui y est ENTRÉ, dans l'ordre. On écrit une rampe — chaque
    /// trame porte son propre numéro — et on compare la sortie à la source
    /// trame par trame. Une erreur de repli déphase la rampe sans rien casser
    /// d'autre : c'est invisible à tout test qui se contente de compter.
    func testLAnneauSeReplieSansPerdreLOrdre() {
        let tampon = TamponAudio()
        var lecteur = LectureEtiree()
        var rampe: [Int16] = []
        var relu: [Int16] = []
        var prochain = 0

        // Les premiers tours ne servent qu'à passer le seuil d'amorçage ; à
        // partir de là c'est un bloc écrit pour un bloc lu, sans boucle
        // d'attente — un test ne doit pas pouvoir tourner sans fin.
        let toursDAmorcage = tampon.seuilAmorcageTrames / 1_024 + 2
        for tour in 0..<80 {
            var bloc: [Int16] = []
            for _ in 0..<1_024 {
                let valeur = Int16(truncatingIfNeeded: prochain)
                bloc.append(contentsOf: [valeur, valeur])
                prochain += 1
            }
            rampe.append(contentsOf: bloc)
            XCTAssertEqual(tampon.ecrire(bloc), 1_024, "aucun débordement attendu ici")
            guard tour >= toursDAmorcage else { continue }
            let rendu = rendre(tampon, trames: 1_024, lecteur: &lecteur)
            XCTAssertEqual(rendu.sonores, 1_024)
            relu.append(contentsOf: rendu.sortie)
        }
        XCTAssertGreaterThan(relu.count, tampon.capaciteTrames * EnTetePaquet.canaux,
                             "on a bien dépassé un tour d'anneau")
        XCTAssertEqual(relu, Array(rampe.prefix(relu.count)))
        XCTAssertEqual(tampon.depassements, 0)
        XCTAssertEqual(tampon.famines, 0)
    }

    func testViderJetteToutEtReamorce() {
        let tampon = TamponAudio()
        var lecteur = LectureEtiree()
        tampon.ecrire(trames(tampon.seuilAmorcageTrames + 500))
        _ = rendre(tampon, trames: 256, lecteur: &lecteur)
        XCTAssertTrue(tampon.amorce)
        tampon.vider()
        XCTAssertEqual(tampon.tramesDisponibles, 0)
        XCTAssertFalse(tampon.amorce)
    }
}
