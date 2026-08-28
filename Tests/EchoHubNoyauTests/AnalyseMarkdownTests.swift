import XCTest
@testable import EchoHubNoyau

/// La batterie PORTÉE de `frontend/src/chat/markdown/tests/parseur.test.ts`, cas
/// pour cas.
///
/// `☠` Deux implémentations qui doivent découper au même endroit méritent les
/// mêmes cas : sinon la réponse lue au navigateur et celle lue sur l'iPhone
/// divergent sans que personne ne le voie. Les cas de tableaux sont absents et
/// c'est délibéré — le module n'en porte pas, une rangée retombe en paragraphe.
final class AnalyseMarkdownTests: XCTestCase {

    private func bloc(_ source: String, _ index: Int = 0) throws -> BlocMarkdown {
        let blocs = AnalyseMarkdown.analyser(source)
        let trouve = try XCTUnwrap(
            blocs.indices.contains(index) ? blocs[index] : nil,
            "bloc \(index) absent — \(blocs.count) bloc(s) pour : \(source)"
        )
        return trouve.bloc
    }

    /// Le texte brut d'une suite de segments : sert à vérifier qu'aucun
    /// caractère reçu n'est perdu.
    private func brut(_ segments: [SegmentInline]) -> String {
        segments.map(\.brut).joined()
    }

    // MARK: - Titres et code

    func testTitreLuAuBonNiveau() throws {
        guard case .titre(let niveau, _) = try bloc("#### Étape 2") else {
            return XCTFail("pas un titre")
        }
        XCTAssertEqual(niveau, 4)
        guard case .titre(let profond, _) = try bloc("###### Détail") else {
            return XCTFail("pas un titre")
        }
        XCTAssertEqual(profond, 6)
    }

    func testDieseSansEspaceResteUnParagraphe() throws {
        guard case .paragraphe = try bloc("#pas un titre") else {
            return XCTFail("aurait dû rester un paragraphe")
        }
    }

    /// `☠` Le cas qui arrive à CHAQUE génération : pendant le streaming, le
    /// dernier bloc de code n'est jamais refermé. Son texte doit rester visible.
    func testBlocDeCodeNonRefermeGardeSonTexte() throws {
        guard case .code(let langage, let texte, let complet) = try bloc("```py\nprint(1)") else {
            return XCTFail("pas un bloc de code")
        }
        XCTAssertEqual(langage, "py")
        XCTAssertEqual(texte, "print(1)")
        XCTAssertFalse(complet)
    }

    func testBlocDeCodeReferme() throws {
        guard case .code(_, let texte, let complet) = try bloc("```\nx = 1\n```") else {
            return XCTFail("pas un bloc de code")
        }
        XCTAssertEqual(texte, "x = 1")
        XCTAssertTrue(complet)
    }

    func testLeTexteApresUnBlocFermeEstUnBlocSuivant() throws {
        let blocs = AnalyseMarkdown.analyser("```\nx = 1\n```\nvoilà.")
        XCTAssertEqual(blocs.count, 2)
        guard case .paragraphe(let contenu) = blocs[1].bloc else { return XCTFail("pas un paragraphe") }
        XCTAssertEqual(brut(contenu), "voilà.")
    }

    // MARK: - Listes

    func testListeImbriquee() throws {
        guard case .liste(let liste) = try bloc("- a\n  - a1\n  - a2\n- b") else {
            return XCTFail("pas une liste")
        }
        XCTAssertEqual(liste.items.count, 2)
        XCTAssertEqual(liste.items[0].sousListe?.items.count, 2)
        XCTAssertNil(liste.items[1].sousListe)
    }

    func testSousListeNumeroteeSousUnePuce() throws {
        guard case .liste(let liste) = try bloc("- étapes\n  1. un\n  2. deux") else {
            return XCTFail("pas une liste")
        }
        XCTAssertEqual(liste.items[0].sousListe?.ordonnee, true)
        XCTAssertEqual(liste.items[0].sousListe?.items.count, 2)
    }

    func testLigneIndenteeRattacheeASonItem() throws {
        guard case .liste(let liste) = try bloc("- premier\n  suite du premier\n- second") else {
            return XCTFail("pas une liste")
        }
        XCTAssertEqual(liste.items.count, 2)
        XCTAssertEqual(brut(liste.items[0].contenu), "premier suite du premier")
    }

    /// L'ordre de reconnaissance compte : `---` n'est pas un item vide.
    func testSeparateurNEstPasUnItemDeListe() throws {
        guard case .separateur = try bloc("---") else { return XCTFail("pas un séparateur") }
    }

    /// Le niveau est l'indentation MESURÉE : un palier codé en dur ferait
    /// disparaître un niveau sur deux selon le gabarit du modèle.
    func testUneIndentationDeTroisEspacesImbriqueAussi() throws {
        guard case .liste(let liste) = try bloc("- a\n   - a1") else {
            return XCTFail("pas une liste")
        }
        XCTAssertEqual(liste.items[0].sousListe?.items.count, 1)
    }

    // MARK: - Inline

    func testTypesDeSegmentsInline() throws {
        guard case .paragraphe(let segments)
            = try bloc("**gras** et `code` et [lien](https://exemple.fr)") else {
            return XCTFail("pas un paragraphe")
        }
        XCTAssertEqual(segments.count, 5)
        guard case .fort = segments[0] else { return XCTFail("attendu fort") }
        guard case .code = segments[2] else { return XCTFail("attendu code") }
        guard case .lien(_, let cible) = segments[4] else { return XCTFail("attendu lien") }
        XCTAssertEqual(cible, "https://exemple.fr")
    }

    /// `☠` L'autre cas de streaming : un marqueur ouvert mais pas refermé
    /// ressort en TEXTE, il ne disparaît pas.
    func testMarqueurInlineNonReferemeResteVisible() throws {
        guard case .paragraphe(let contenu) = try bloc("**gras jamais fermé") else {
            return XCTFail("pas un paragraphe")
        }
        XCTAssertEqual(brut(contenu), "**gras jamais fermé")
    }

    /// `_souligné_` n'est pas reconnu exprès : il découperait
    /// `nom_de_variable` en emphase au milieu d'un identifiant, cas bien plus
    /// fréquent qu'un italique dans une réponse technique.
    func testLesTiretsBasNeCoupentPasUnIdentifiant() throws {
        let source = "la variable nom_de_variable_ici est intacte"
        guard case .paragraphe(let contenu) = try bloc(source) else {
            return XCTFail("pas un paragraphe")
        }
        XCTAssertEqual(brut(contenu), source)
    }

    func testCitationReconnue() throws {
        guard case .citation(let contenu) = try bloc("> une citation") else {
            return XCTFail("pas une citation")
        }
        XCTAssertEqual(brut(contenu), "une citation")
    }

    // MARK: - Rien ne disparaît

    /// La garantie centrale du module : la concaténation des segments d'un
    /// paragraphe redonne exactement la source.
    func testRienNeDisparaitDansUnParagraphe() throws {
        let source = "un *mot* et `du code` et du texte après"
        guard case .paragraphe(let contenu) = try bloc(source) else {
            return XCTFail("pas un paragraphe")
        }
        XCTAssertEqual(brut(contenu), "un mot et du code et du texte après")
    }

    func testChaineVideNeProduitAucunBloc() {
        XCTAssertTrue(AnalyseMarkdown.analyser("").isEmpty)
    }

    /// `☠` L'identité vient du RANG, pas du contenu : deux séparateurs
    /// identiques dans une réponse ne doivent pas se confondre dans une
    /// `ForEach`, sinon une ligne disparaît sans erreur.
    func testDeuxBlocsIdentiquesGardentDesIdentitesDistinctes() {
        let blocs = AnalyseMarkdown.analyser("---\n\n---")
        XCTAssertEqual(blocs.count, 2)
        XCTAssertNotEqual(blocs[0].id, blocs[1].id)
    }
}
