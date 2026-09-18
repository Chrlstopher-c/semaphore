import XCTest
@testable import DuplexNoyau

/// L'épreuve du rattrapage de dérive, simulée de bout en bout : un PC qui ne
/// compte pas le temps à la même vitesse que l'iPhone, et une écoute qui dure.
///
/// `☠` Ce banc est la seule chose qui distingue « le correcteur calcule quelque
/// chose » de « le correcteur tient le tampon ». Chaque cas corrigé est doublé
/// d'un TÉMOIN à facteur figé, qui doit ÉCHOUER là où le correcteur réussit —
/// un banc qui ne sait pas échouer ne prouve rien.
final class EcouteLongueTests: XCTestCase {

    /// Un bloc de rendu de l'iPhone. 256 trames ≈ 5,3 ms, l'ordre de grandeur
    /// que sert `AVAudioEngine` sur un iPhone XS.
    private static let tramesParBloc = 256
    /// 14 000 blocs ≈ 75 s de son simulé. La durée n'est pas confortable, elle
    /// est CALCULÉE : à 0,2 % de dérive le tampon perd une demi-trame par bloc,
    /// il lui en faut donc ~9 600 pour épuiser les 100 ms de la cible. En deçà,
    /// le témoin non corrigé ne meurt pas de faim et ne prouve rien.
    private static let blocs = 14_000

    /// Fait tourner l'écoute. `derive` > 0 : le PC va plus vite que l'iPhone.
    /// Rend les remplissages observés bloc par bloc, et les compteurs du tampon.
    private func simuler(
        derive: Double, corrigee: Bool
    ) -> (remplissages: [Double], famines: Int, depassements: Int, facteur: Double) {
        let tampon = TamponAudio()
        var lecteur = LectureEtiree()
        var correction = CorrectionDerive()
        var remplissages: [Double] = []
        var dette = 0.0
        var sortie = [Int16](repeating: 0, count: Self.tramesParBloc * EnTetePaquet.canaux)

        for _ in 0..<Self.blocs {
            // Le PC a livré, pendant ce bloc, ce que SON horloge a produit.
            dette += Double(Self.tramesParBloc) * (1 + derive)
            let aLivrer = Int(dette)
            dette -= Double(aLivrer)
            tampon.ecrire([Int16](repeating: 500, count: aLivrer * EnTetePaquet.canaux))

            let facteur = corrigee ? correction.observer(remplissageMs: tampon.remplissageMs) : 1
            sortie.withUnsafeMutableBufferPointer {
                tampon.lire(
                    dans: $0.baseAddress!, trames: Self.tramesParBloc,
                    facteur: facteur, lecteur: &lecteur
                )
            }
            remplissages.append(tampon.remplissageMs)
        }
        return (remplissages, tampon.famines, tampon.depassements, correction.facteur)
    }

    /// Le régime établi : la seconde moitié de l'écoute, une fois le correcteur
    /// arrivé à sa consigne. La première moitié contient l'amorçage.
    private func regimeEtabli(_ remplissages: [Double]) -> [Double] {
        Array(remplissages.suffix(remplissages.count / 2))
    }

    // MARK: - PC plus rapide que l'iPhone

    func testUnPCPlusRapideNeFaitPasEnflerLeTampon() {
        let corrige = simuler(derive: 0.002, corrigee: true)
        let etabli = regimeEtabli(corrige.remplissages)
        XCTAssertLessThan(etabli.max() ?? 0, 130, "le tampon reste près de la cible")
        XCTAssertGreaterThan(etabli.min() ?? 0, 70)
        XCTAssertEqual(corrige.famines, 0)
        XCTAssertEqual(corrige.depassements, 0)
        XCTAssertGreaterThan(corrige.facteur, 1, "on lit plus vite pour rattraper")

        // Le témoin : même dérive, facteur figé. Le tampon DOIT déraper.
        let temoin = simuler(derive: 0.002, corrigee: false)
        XCTAssertGreaterThan(
            regimeEtabli(temoin.remplissages).max() ?? 0, 150,
            "sans correction, le tampon enfle — si ce témoin passe, le banc ne prouve rien"
        )
    }

    // MARK: - PC plus lent que l'iPhone

    func testUnPCPlusLentNeFaitPasMourirDeFaim() {
        let corrige = simuler(derive: -0.002, corrigee: true)
        let etabli = regimeEtabli(corrige.remplissages)
        XCTAssertGreaterThan(etabli.min() ?? 0, 60, "le tampon ne se vide pas")
        XCTAssertLessThan(etabli.max() ?? 0, 130)
        XCTAssertEqual(corrige.famines, 0)
        XCTAssertLessThan(corrige.facteur, 1, "on ralentit pour laisser le tampon se refaire")

        let temoin = simuler(derive: -0.002, corrigee: false)
        XCTAssertGreaterThan(
            temoin.famines, 0,
            "sans correction, le tampon finit à sec — sinon le banc ne prouve rien"
        )
    }

    // MARK: - Deux horloges accordées

    /// Le contrôle de référence : sans dérive, le correcteur ne doit RIEN faire.
    /// Un correcteur qui bouge sur une entrée parfaite fabrique le défaut qu'il
    /// prétend corriger.
    func testSansDeriveLeCorrecteurNeBougePas() {
        let neutre = simuler(derive: 0, corrigee: true)
        XCTAssertEqual(neutre.facteur, 1, accuracy: 1e-4)
        XCTAssertEqual(neutre.famines, 0)
        XCTAssertEqual(neutre.depassements, 0)
        let etabli = regimeEtabli(neutre.remplissages)
        XCTAssertEqual(etabli.max() ?? 0, CorrectionDerive.cibleMs, accuracy: 10)
    }

    // MARK: - Trous de séquence

    /// Un flux troué reste écoutable : chaque trou devient exactement sa durée
    /// en silence, la lecture ne décroche pas, et rien ne se retransmet.
    func testUnFluxTroueResteEcoutable() {
        let tampon = TamponAudio()
        var suivi = SuiviFlux()
        var lecteur = LectureEtiree()
        var sequence: UInt32 = 1
        var sortie = [Int16](repeating: 0, count: Self.tramesParBloc * EnTetePaquet.canaux)

        for bloc in 0..<2_000 {
            // Un paquet sur cinquante disparaît en route.
            for _ in 0..<2 {
                if sequence % 50 != 0 {
                    if case let .trou(manquantes) = suivi.accueillir(sequence: sequence) {
                        tampon.ecrireSilence(trames: manquantes)
                    }
                    tampon.ecrire([Int16](
                        repeating: 500,
                        count: EnTetePaquet.tramesParPaquet * EnTetePaquet.canaux
                    ))
                }
                sequence += 1
            }
            if bloc > 40 {
                sortie.withUnsafeMutableBufferPointer {
                    tampon.lire(
                        dans: $0.baseAddress!, trames: Self.tramesParBloc,
                        facteur: 1, lecteur: &lecteur
                    )
                }
            }
        }
        XCTAssertGreaterThan(suivi.trous, 30, "des trous ont bien été vus")
        XCTAssertEqual(suivi.ruptures, 0)
        XCTAssertEqual(tampon.famines, 0, "le silence inséré a tenu la lecture")
    }
}
