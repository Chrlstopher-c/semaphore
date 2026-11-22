import Foundation
import Testing
@testable import VigieNoyau

// Les cas d'événement ajoutés au contrat, et le repli `.inconnu` pour tout ce qui ne colle pas.

private func evt(_ json: String) throws -> Evenement {
    try JSONDecoder().decode(Evenement.self, from: Data(json.utf8))
}

@Test func messageAvecAuteurEtUuidOuSansEux() throws {
    #expect(try evt(#"{"type":"message","texte":"Vas-y.","uuid":"u-1","auteur":"chris"}"#)
        == .message(texte: "Vas-y.", uuid: "u-1", auteur: "chris"))
    #expect(try evt(#"{"type":"message","texte":"Vas-y."}"#) == .message(texte: "Vas-y.", uuid: nil, auteur: nil))
}

@Test func tachesLisentLEtatEtTolerentLInconnu() throws {
    let json = #"{"type":"taches","taches":[{"contenu":"a","etat":"fait"},{"contenu":"b","etat":"en_cours"},"#
        + #"{"contenu":"c","etat":"bizarre"},{"contenu":"d"},"oups"]}"#
    #expect(try evt(json) == .taches([
        TacheFil(contenu: "a", etat: .fait), TacheFil(contenu: "b", etat: .enCours),
        TacheFil(contenu: "c", etat: .attente), TacheFil(contenu: "d", etat: .attente),
    ]))
}

@Test func tourFiniAvecJetonsFacultatifs() throws {
    #expect(try evt(#"{"type":"tour_fini","dureeMs":1500.0,"contexte":2048,"entree":10,"sortie":4,"coutUsd":0.02}"#)
        == .tourFini(dureeMs: 1500, contexte: 2048, entree: 10, sortie: 4, coutUsd: 0.02))
    #expect(try evt(#"{"type":"tour_fini","dureeMs":1,"contexte":2}"#)
        == .tourFini(dureeMs: 1, contexte: 2, entree: nil, sortie: nil, coutUsd: nil))
}

@Test func dialogueResoluEtFichiersDuTour() throws {
    let dialogue = #"{"id":"d","titre":"Ville ?","options":[{"libelle":"Paris","description":""}],"#
        + #""multiple":false,"saisie":null,"coches":[]}"#
    #expect(try evt(#"{"type":"dialogue_resolu","dialogue":\#(dialogue),"reponses":["Paris"],"decision":"autoriser"}"#)
        == .dialogueResolu(dialogue: try JSONDecoder().decode(Dialogue.self, from: Data(dialogue.utf8)),
                           reponses: ["Paris"], decision: "autoriser"))
    let fichiers = #"{"type":"fichiers_tour","tour":"t-1","fichiers":[{"chemin":"a.swift","etat":"modifie","ajouts":3,"#
        + #""suppressions":1,"binaire":false},{"chemin":"b","etat":"ajoute","ajouts":"beaucoup"}]}"#
    #expect(try evt(fichiers) == .fichiersTour(tour: "t-1", fichiers: [
        FichierModifie(chemin: "a.swift", etat: "modifie", ajouts: 3, suppressions: 1, binaire: false),
    ]), "un fichier mal formé est écarté, la liste reste")
    #expect(try evt(#"{"type":"tour_annule","tour":"t-1"}"#) == .tourAnnule(tour: "t-1"))
}

@Test func mediasEtRelais() throws {
    #expect(try evt(#"{"type":"image","fichier":"f1","nom":"a.png","mime":"image/png","taille":12,"origine":"outil"}"#)
        == .image(fichier: "f1", nom: "a.png", mime: "image/png", taille: 12, origine: "outil", agent: nil))
    #expect(try evt(#"{"type":"fichier","fichier":"f2","nom":"n.pdf","mime":"application/pdf","#
        + #""taille":9,"legende":null}"#)
        == .fichier(fichier: "f2", nom: "n.pdf", mime: "application/pdf", taille: 9, legende: nil))
    #expect(try evt(#"{"type":"relais","sens":"sortant","session":"s-9","titre":"Autre","texte":"salut"}"#)
        == .relais(sens: "sortant", session: "s-9", titre: "Autre", texte: "salut"))
}

@Test func typesHorsContratRestentInconnus() throws {
    for type in ["artefact", "widget", "chapitre", "flux", "integration", "duo_main"] {
        #expect(try evt(#"{"type":"\#(type)","x":1}"#) == .inconnu(type: type))
    }
}

@Test func typeConnuMalFormeDevientInconnu() throws {
    #expect(try evt(#"{"type":"etape","resume":1,"suite":"s"}"#) == .inconnu(type: "etape"))
    #expect(try evt(#"{"type":"tour_fini","dureeMs":"vite","contexte":1}"#) == .inconnu(type: "tour_fini"))
    #expect(try evt(#"{"texte":"sans type"}"#) == .inconnu(type: ""))
}
