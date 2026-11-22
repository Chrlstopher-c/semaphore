import Foundation
import Testing
@testable import VigieNoyau

// Session de poste : `claudeSessionId` = conversation Claude Code, `cwd` = dossier.
private func sessionDePoste(
    _ id: String, titre: String = "Refonte", cwd: String = "/srv/depot/projet", conversation: String? = nil
) throws -> Session {
    let conversationJSON = conversation.map { "\"\($0)\"" } ?? "null"
    return try decoderSession(
        id: id, moteur: "sdk", titre: titre, cwd: cwd, archivee: false, claude: conversationJSON, distant: "null")
}

// Session claude.ai : `distant` porte la conversation et le dossier réel annoncés par la session.
private func sessionDistante(
    _ id: String, titre: String = "Refonte", conversation: String? = nil, cwdReel: String? = nil, archivee: Bool = false
) throws -> Session {
    let conversationJSON = conversation.map { "\"\($0)\"" } ?? "null"
    let cwdReelJSON = cwdReel.map { "\"\($0)\"" } ?? "null"
    let distant = """
    {"compte":"c","idDistant":"d-\(id)","connexion":"connectee","probleme":null,
    "conversation":\(conversationJSON),"cwdReel":\(cwdReelJSON),"machineReelle":"tour"}
    """
    return try decoderSession(
        id: id, moteur: "claude_ai", titre: titre, cwd: "/", archivee: archivee, claude: "null", distant: distant)
}

private func decoderSession(
    id: String, moteur: String, titre: String, cwd: String, archivee: Bool, claude: String, distant: String
) throws -> Session {
    let json = """
    {"id":"\(id)","machine":"tour","projet":{"machine":"tour","chemin":"\(cwd)","nom":"projet"},
    "cwd":"\(cwd)","titre":"\(titre)","objectif":null,"modele":"m","compte":"c","autonomie":false,
    "statut":"attente","contexte":{"tokens":1,"max":10},"etapes":0,"compactions":0,"claudeSessionId":\(claude),
    "tmux":null,"attachee":false,"pilotee":false,"moteur":"\(moteur)","archivee":\(archivee),"distant":\(distant),
    "creeLe":"2026-11-22T10:00:00Z","majLe":"2026-11-22T10:00:00Z"}
    """
    return try JSONDecoder().decode(Session.self, from: Data(json.utf8))
}

@Test func rapprochementParConversation() throws {
    let poste = try sessionDePoste("p", titre: "Titre local", conversation: "conv-1")
    let distante = try sessionDistante("d", titre: "Autre titre", conversation: "conv-1")
    #expect(JumellesDistantes.jumelles([poste, distante]) == ["p": "d"])
    #expect(JumellesDistantes.sansDoublons([poste, distante]).map(\.id) == ["p"])
}

@Test func laConversationPrimeSurLeTitre() throws {
    let poste = try sessionDePoste("p", titre: "Refonte", conversation: "conv-1")
    let parTitre = try sessionDistante("titre", titre: "Refonte", cwdReel: "/srv/depot/projet")
    let parConversation = try sessionDistante("conv", titre: "Ailleurs", conversation: "conv-1")
    #expect(JumellesDistantes.jumelles([poste, parTitre, parConversation]) == ["p": "conv"])
}

@Test func reperageParTitreEtDossierReelSansConversation() throws {
    let poste = try sessionDePoste("p", titre: "Refonte", cwd: "/srv/depot/projet/")
    let distante = try sessionDistante("d", titre: "  Refonte ", cwdReel: "/srv/depot/projet")
    #expect(JumellesDistantes.jumelles([poste, distante]) == ["p": "d"])
    #expect(JumellesDistantes.lecture("p", [poste, distante]) == "p")
    #expect(JumellesDistantes.ecriture("p", [poste, distante]) == "d")
}

@Test func uneDistanteArchiveeNEstJamaisJumelle() throws {
    let poste = try sessionDePoste("p", conversation: "conv-1")
    let archivee = try sessionDistante("d", conversation: "conv-1", archivee: true)
    #expect(JumellesDistantes.jumelles([poste, archivee]).isEmpty)
    #expect(JumellesDistantes.sansDoublons([poste, archivee]).map(\.id) == ["p", "d"])
}

@Test func sessionSansJumelleEstInchangee() throws {
    let poste = try sessionDePoste("p", titre: "Seule", conversation: "conv-9")
    let distante = try sessionDistante("d", titre: "Autre", conversation: "conv-1")
    let sessions = [poste, distante]
    #expect(JumellesDistantes.jumelles(sessions).isEmpty)
    #expect(JumellesDistantes.sansDoublons(sessions).map(\.id) == ["p", "d"])
    #expect(JumellesDistantes.lecture("p", sessions) == "p")
    #expect(JumellesDistantes.ecriture("d", sessions) == "d")
}

@Test func lectureEtEcritureVontALaBonneSession() throws {
    let poste = try sessionDePoste("p", conversation: "conv-1")
    let distante = try sessionDistante("d", conversation: "conv-1")
    let sessions = [poste, distante]
    #expect(JumellesDistantes.lecture("d", sessions) == "p")
    #expect(JumellesDistantes.lecture("p", sessions) == "p")
    #expect(JumellesDistantes.ecriture("p", sessions) == "d")
    #expect(JumellesDistantes.ecriture("d", sessions) == "d")
    #expect(JumellesDistantes.lecture("inconnue", sessions) == "inconnue")
}

@Test func champFacultatifMalFormeNeFaitPasPerdreLaSession() throws {
    let json = """
    {"compte":"c","idDistant":"d","connexion":"connectee","probleme":null,"cwd":12,"conversation":"conv-1"}
    """
    let distant = try JSONDecoder().decode(SessionDistante.self, from: Data(json.utf8))
    #expect(distant.cwd == nil)
    #expect(distant.conversation == "conv-1")
    #expect(distant.cwdReel == nil && distant.machineReelle == nil)
}
