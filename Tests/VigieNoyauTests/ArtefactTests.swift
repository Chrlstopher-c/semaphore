import Foundation
import Testing

@testable import VigieNoyau

/// `☠` Le type `artefact` est arrivé cette nuit côté serveur (migration 30,
/// `harness/control-plane/registre/types.ts`) : un contenu que l'orchestrateur
/// produit lui-même — script shell/Python/Lua, page HTML — affiché dans le fil
/// au lieu d'être noyé dans un bloc de texte. Sa charge utile est EXACTEMENT
/// celle d'une pièce jointe (`PieceJointeApi`), même route de lecture.
@Suite("Artefacts — décodage et reconnaissance du langage")
struct ArtefactTests {
    private func donnees(_ texte: String) -> Data { Data(texte.utf8) }

    // MARK: - Décodage de l'évènement

    @Test("un évènement « artefact » se décode avec sa pièce (nom, type MIME, taille, url)")
    func decodageEvenementArtefact() throws {
        let corps = donnees(
            """
            {"seq": 12, "type": "artefact", "contenu": "demo.html", "at": 1755400000000,
             "model": "claude-opus-5", "effort": "high", "detail": null, "resultat": null,
             "pieces": [{"nom": "demo.html", "type": "text/html", "taille": 342,
                         "url": "/api/harness/orchestrator/conversations/c1/pieces/1700-demo.html"}]}
            """
        )
        let evenement = try JSONDecoder().decode(EvenementApi.self, from: corps)
        #expect(evenement.type == .artefact)
        #expect(evenement.contenu == "demo.html")
        #expect(evenement.pieces.count == 1)
        #expect(evenement.pieces[0].type == "text/html")
        #expect(evenement.pieces[0].taille == 342)
        #expect(evenement.pieces[0].url.hasSuffix("demo.html"))
    }

    @Test("un évènement « artefact » sans pièce reste décodable — le trou se gère à l'affichage")
    func decodageEvenementArtefactSansPiece() throws {
        let corps = donnees(
            """
            {"seq": 13, "type": "artefact", "contenu": "run.py", "at": 1, "model": null,
             "effort": null, "detail": null, "resultat": null, "pieces": []}
            """
        )
        let evenement = try JSONDecoder().decode(EvenementApi.self, from: corps)
        #expect(evenement.type == .artefact)
        #expect(evenement.pieces.isEmpty)
    }

    // MARK: - Segmentation : le bloc dédié, pas un « fait » générique

    @Test("un artefact segmenté porte sa pièce, pas seulement un texte")
    func segmentationPorteLaPiece() throws {
        let evenement = EvenementApi(
            seq: 5, type: .artefact, contenu: "outil.sh", at: 1000, model: "sonnet", effort: "medium",
            detail: nil, resultat: nil,
            pieces: [PieceJointeApi(nom: "outil.sh", type: "text/x-sh", taille: 44, url: "/pieces/outil.sh")]
        )
        let segments = SegmentationFil.segmenter([evenement])
        guard case .tour(let tour) = segments.first, case .artefact(_, let piece, _) = tour.blocs.first else {
            Issue.record("le segment n'est pas un tour portant un bloc .artefact")
            return
        }
        #expect(piece?.nom == "outil.sh")
        #expect(piece?.type == "text/x-sh")
    }

    /// `☠` AVANT la migration 30 côté client, ce même évènement retombait dans
    /// le `default:` de `Constructeur.absorber` et se lisait `.fait` — un
    /// simple texte, sans la pièce : aucun code à lire, aucun téléchargement
    /// possible. C'est précisément le défaut que ce test interdit de réintroduire.
    @Test("un artefact ne se replie jamais sur le bloc « fait » générique")
    func nePasReplierSurFait() throws {
        let evenement = EvenementApi(
            seq: 7, type: .artefact, contenu: "demo.html", at: 1, model: nil, effort: nil,
            detail: nil, resultat: nil,
            pieces: [PieceJointeApi(nom: "demo.html", type: "text/html", taille: 10, url: "/pieces/demo.html")]
        )
        let segments = SegmentationFil.segmenter([evenement])
        guard case .tour(let tour) = segments.first else {
            Issue.record("segment attendu : .tour")
            return
        }
        for bloc in tour.blocs {
            if case .fait = bloc { Issue.record("un artefact ne doit jamais devenir un .fait générique") }
        }
    }

    @Test("un artefact sans pièce segmente avec piece == nil, sans planter")
    func segmentationSansPiece() throws {
        let evenement = EvenementApi(
            seq: 9, type: .artefact, contenu: "demo.html", at: 1, model: nil, effort: nil,
            detail: nil, resultat: nil, pieces: []
        )
        let segments = SegmentationFil.segmenter([evenement])
        guard case .tour(let tour) = segments.first, case .artefact(_, let piece, _) = tour.blocs.first else {
            Issue.record("le segment n'est pas un tour portant un bloc .artefact")
            return
        }
        #expect(piece == nil)
    }

    // MARK: - Reconnaissance du langage par extension

    @Test("les quatre extensions du périmètre fermé sont reconnues")
    func extensionsReconnues() {
        #expect(LangageArtefact.depuis(nomFichier: "demo.html") == .html)
        #expect(LangageArtefact.depuis(nomFichier: "run.sh") == .sh)
        #expect(LangageArtefact.depuis(nomFichier: "outil.py") == .py)
        #expect(LangageArtefact.depuis(nomFichier: "script.lua") == .lua)
    }

    @Test("l'extension se reconnaît sans égard à la casse")
    func extensionInsensibleCasse() {
        #expect(LangageArtefact.depuis(nomFichier: "DEMO.HTML") == .html)
        #expect(LangageArtefact.depuis(nomFichier: "Run.Sh") == .sh)
    }

    @Test("un nom à extensions multiples ne retient que la dernière")
    func extensionMultiple() {
        #expect(LangageArtefact.depuis(nomFichier: "1700000000000-demo.html") == .html)
        #expect(LangageArtefact.depuis(nomFichier: "archive.tar.py") == .py)
    }

    @Test("hors du périmètre fermé, aucun langage n'est deviné")
    func extensionHorsPerimetre() {
        #expect(LangageArtefact.depuis(nomFichier: "notes.txt") == nil)
        #expect(LangageArtefact.depuis(nomFichier: "binaire.exe") == nil)
        #expect(LangageArtefact.depuis(nomFichier: "sans_extension") == nil)
        #expect(LangageArtefact.depuis(nomFichier: "") == nil)
    }

    @Test("seul HTML bascule code / rendu")
    func seulHtmlSeRend() {
        #expect(LangageArtefact.html.seRend)
        #expect(!LangageArtefact.sh.seRend)
        #expect(!LangageArtefact.py.seRend)
        #expect(!LangageArtefact.lua.seRend)
    }
}
