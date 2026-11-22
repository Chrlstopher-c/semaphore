import Foundation
import Testing
@testable import VigieNoyau

// Le fil réel anonymisé (textes remplacés par des x) : chaque événement d'un type connu se décode, et le fil se
// structure sans crash. Le fichier n'est jamais copié dans le dépôt : il se donne par la variable QUART_FIL_REEL.

private let cheminFilReel: String? = ProcessInfo.processInfo.environment["QUART_FIL_REEL"]

private let typesConnus: Set<String> = [
    "message", "texte", "reflexion", "outil", "resultat_outil", "sous_agent", "taches", "dialogue_resolu",
    "fichiers_tour", "tour_annule", "image", "fichier", "relais", "etape", "objectif_atteint", "question",
    "compaction", "relance", "tour_fini", "erreur",
]

private struct LigneAnonyme: Decodable {
    let seq: Int
    let evt: Evenement
}

private func typeDe(_ evt: Evenement) -> String? {
    if case .inconnu(let type) = evt { return type }
    return nil
}

@Test(.enabled(if: cheminFilReel != nil))
func filReelDecodeChaqueEvenementConnu() throws {
    let chemin = try #require(cheminFilReel)
    let lignes = try String(contentsOfFile: chemin, encoding: .utf8).split(separator: "\n")
    let decodeur = JSONDecoder()
    var evts: [EvenementDate] = []
    var connusInconnus: [String] = []
    for ligne in lignes {
        let anonyme = try decodeur.decode(LigneAnonyme.self, from: Data(ligne.utf8))
        if let type = typeDe(anonyme.evt), typesConnus.contains(type) { connusInconnus.append(type) }
        evts.append(EvenementDate(seq: anonyme.seq, sessionId: "anonyme", ts: "", evt: anonyme.evt))
    }
    #expect(evts.count == lignes.count, "chaque ligne se décode")
    #expect(connusInconnus.isEmpty, "aucun type connu ne devient inconnu")
}

@Test(.enabled(if: cheminFilReel != nil))
func filReelSeStructureEtSeBloque() throws {
    let chemin = try #require(cheminFilReel)
    let decodeur = JSONDecoder()
    let lignes = try String(contentsOfFile: chemin, encoding: .utf8).split(separator: "\n")
    let evts = try lignes.map { ligne -> EvenementDate in
        let anonyme = try decodeur.decode(LigneAnonyme.self, from: Data(ligne.utf8))
        return EvenementDate(seq: anonyme.seq, sessionId: "anonyme", ts: "", evt: anonyme.evt)
    }
    let blocs = BlocsFil.depuis(StructureFil.structurer(evts))
    #expect(blocs.count > 0)
    let groupes = blocs.filter { if case .actions = $0 { return true } else { return false } }
    #expect(!groupes.isEmpty, "le fil réel contient des suites d'actions")
}
