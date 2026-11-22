import Foundation
import Testing
@testable import VigieNoyau

private func evt(_ seq: Int, ts: String = "2026-11-22T08:00:00.000Z") -> EvenementDate {
    EvenementDate(seq: seq, sessionId: "s", ts: ts, evt: .texte(texte: "\(seq)", agent: nil))
}

@Test func changerDeNoeudChangeLaSourceDesNumeros() {
    let tour = CurseurFil.origine(noeud: "noeud-a")
    #expect(CurseurFil.origine(noeud: "noeud-b") != tour, "deux nœuds numérotent leurs fils à part")
    #expect(CurseurFil.origine(noeud: "noeud-a") == tour, "même nœud : même source, le curseur reste valable")
    #expect(CurseurFil.origine(noeud: nil) != tour, "le lien direct ne se confond pas avec un nœud")
}

@Test func unCurseurDunAutreNoeudNestPasCoherentAvecLeRelais() {
    // Ancien nœud : dernier événement 30500 à 05:00. Nouveau nœud : le fil va de 29627 à 29938, à 17:26.
    let curseur = evt(30_500, ts: "2026-11-22T05:00:00.000Z")
    let relais = [evt(29_627, ts: "2026-11-22T17:00:00.000Z"), evt(29_938, ts: "2026-11-22T17:26:00.000Z")]
    #expect(!CurseurFil.coherent(curseur, avec: relais), "le relais n'a pas cet événement : il est derrière")
    #expect(CurseurFil.coherent(evt(29_938, ts: "2026-11-22T17:26:00.000Z"), avec: relais))
}

@Test func unMemeNumeroAvecUneAutreDateNestPasLeMemeEvenement() {
    let curseur = evt(100, ts: "2026-11-22T10:00:00.000Z")
    #expect(!CurseurFil.coherent(curseur, avec: [evt(100, ts: "2026-11-22T11:00:00.000Z")]))
}

@Test func sessionPlusRecenteQueLeDernierEvenementDeclencheLeControle() {
    let dernier = "2026-11-22T14:00:00.000Z"
    #expect(CurseurFil.sessionPlusRecente(majLe: "2026-11-22T17:26:00.000Z", que: dernier))
    #expect(!CurseurFil.sessionPlusRecente(majLe: "2026-11-22T13:00:00.000Z", que: dernier))
    #expect(!CurseurFil.sessionPlusRecente(majLe: "illisible", que: dernier), "une date illisible ne déclenche rien")
}
