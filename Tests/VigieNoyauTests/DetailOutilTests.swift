import Foundation
import Testing
@testable import VigieNoyau

// Le détail d'un appel d'outil : Bash, Edit, Write, et le repli pour le reste ou une entrée illisible.

private func appel(_ nom: String, _ detail: String, resultat: String? = nil) -> AppelOutil {
    var appel = AppelOutil(id: 1, outilId: "t1", nom: nom, resume: "résumé", detail: detail)
    if let resultat { appel.resultat = AppelOutil.Resultat(extrait: resultat, erreur: false) }
    return appel
}

@Test func bashAGardeSaCommandeEtSaSortie() {
    let entree = #"{"command":"ls -l","description":"Liste le dossier"}"#
    let detail = DetailOutil.depuis(appel("Bash", entree, resultat: "a b"))
    #expect(detail.titre == "Liste le dossier")
    #expect(detail.sections == [
        DetailOutil.Section(libelle: "Commande", contenu: "ls -l", code: true),
        DetailOutil.Section(libelle: "Sortie", contenu: "a b", code: true),
    ])
    #expect(detail.diff == nil && detail.chemin == nil)
}

@Test func editDonneLeCheminEtLeDiff() {
    let entree = #"{"file_path":"/p/a.txt","old_string":"un\ndeux","new_string":"trois"}"#
    let detail = DetailOutil.depuis(appel("Edit", entree))
    #expect(detail.chemin == "/p/a.txt")
    #expect(detail.suppressions == 2 && detail.ajouts == 1)
    #expect(detail.diff == [
        DetailOutil.LigneDiff(genre: .retrait, texte: "un"),
        DetailOutil.LigneDiff(genre: .retrait, texte: "deux"),
        DetailOutil.LigneDiff(genre: .ajout, texte: "trois"),
    ])
}

@Test func writeEstTouteEnAjout() {
    let detail = DetailOutil.depuis(appel("Write", #"{"file_path":"/p/n.md","content":"a\nb\nc"}"#))
    #expect(detail.chemin == "/p/n.md" && detail.ajouts == 3 && detail.suppressions == 0)
    #expect(detail.diff?.allSatisfy { $0.genre == .ajout } == true)
}

@Test func lectureGardeLEntreeEnJsonIndente() {
    let detail = DetailOutil.depuis(appel("Read", #"{"file_path":"/p/a.txt"}"#, resultat: "contenu"))
    #expect(detail.titre == "résumé")
    #expect(detail.sections.first?.libelle == "Entrée")
    #expect(detail.sections.first?.contenu.contains("\"file_path\"") == true)
    #expect(detail.sections.last == DetailOutil.Section(libelle: "Sortie", contenu: "contenu", code: true))
}

@Test func entreeIllisibleRestetBrute() {
    let detail = DetailOutil.depuis(appel("Bash", #"{"command":"ls -"#))
    #expect(detail.sections == [DetailOutil.Section(libelle: "Entrée", contenu: #"{"command":"ls -"#, code: true)])
}
