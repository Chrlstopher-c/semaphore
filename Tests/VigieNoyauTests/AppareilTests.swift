import Foundation
import Testing
@testable import VigieNoyau

// L'accès à distance : ce que le relais rend se décode, les routes encodent les chemins, chaque fichier a son aperçu.

@Test func listeDeDossierDecode() throws {
    let json = """
    {"chemin":"/home/pi","parent":"/home","accueil":"/home/pi","entrees":[
      {"nom":"quart-apercu","type":"dossier","taille":4096,"modifie":"2026-09-28T17:00:00.000Z","cache":false},
      {"nom":".bashrc","type":"fichier","taille":3523,"modifie":"2026-09-28T17:00:00.000Z","cache":true}]}
    """
    let l = try JSONDecoder().decode(ListeDossier.self, from: Data(json.utf8))
    #expect(l.entrees.count == 2)
    #expect(l.entrees[0].type == .dossier)
    #expect(l.entrees[1].cache)
}

@Test func routesEncodentLesChemins() {
    #expect(Route.fichiers("pi", chemin: nil) == "/api/machines/pi/fichiers")
    #expect(Route.fichier("pi", chemin: "/home/pi/a b&c+d.txt")
        == "/api/machines/pi/fichier?chemin=/home/pi/a%20b%26c%2Bd.txt")
    #expect(Route.terminal("tour", tmux: "cc-1", colonnes: 80, lignes: 24)
        == "/api/terminal?machine=tour&colonnes=80&lignes=24&tmux=cc-1")
}

@Test func apercuSelonLeFichier() {
    #expect(ApercuFichier.de("Photo.JPG") == .image)
    #expect(ApercuFichier.de("note.md") == .markdown)
    #expect(ApercuFichier.de("deploy.sh") == .texte)
    #expect(ApercuFichier.de("Dockerfile") == .texte)
    #expect(ApercuFichier.de(".bashrc") == .texte)
    #expect(ApercuFichier.de("rapport.pdf") == .quickLook)
    #expect(ApercuFichier.de("film.mp4") == .quickLook)
    #expect(CheminDistant.joindre("/", "etc") == "/etc")
    #expect(CheminDistant.joindre("/home/pi", "a") == "/home/pi/a")
    #expect(CheminDistant.nom("/home/pi/note.md") == "note.md")
}
