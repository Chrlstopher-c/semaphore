import Foundation
import Testing
@testable import VigieNoyau

private actor Suivi {
    private var enCours = 0
    private var pic = 0
    private var annules = 0

    func entrer() {
        enCours += 1
        pic = max(pic, enCours)
    }

    func sortir() { enCours -= 1 }
    func annule() { annules += 1 }
    func maximum() -> Int { pic }
    func nombreAnnules() -> Int { annules }
}

@Test func lOrdreDeLectureTientMemeSiLesPreparationsRepondentDansLeDesordre() async {
    let file = FileVocale<String>(enVol: 3)
    let delais: [String: Int] = ["un": 80, "deux": 5, "trois": 30]
    for texte in ["un", "deux", "trois"] {
        file.ajouter(texte) { t in
            try? await Task.sleep(for: .milliseconds(delais[t] ?? 0))
            return t.uppercased()
        }
    }
    var sortie: [String] = []
    while let morceau = file.prochain() {
        if let audio = await morceau.audio.value { sortie.append(audio) }
    }
    #expect(sortie == ["UN", "DEUX", "TROIS"])
    #expect(file.vide)
}

@Test func auPlusDeuxPreparationsEnVolAvecDeuxDansLaFile() async {
    let suivi = Suivi()
    let file = FileVocale<Int>(enVol: 2)
    for n in 1...5 {
        file.ajouter("morceau \(n)") { _ in
            await suivi.entrer()
            try? await Task.sleep(for: .milliseconds(30))
            await suivi.sortir()
            return n
        }
    }
    var sortie: [Int] = []
    while let morceau = file.prochain() {
        if let audio = await morceau.audio.value { sortie.append(audio) }
    }
    #expect(sortie == [1, 2, 3, 4, 5])
    #expect(await suivi.maximum() <= 2)
}

@Test func annulerCoupeLesPreparationsEnCoursEtVideLaFile() async {
    let suivi = Suivi()
    let file = FileVocale<Int>(enVol: 2)
    for n in 1...3 {
        file.ajouter("morceau \(n)") { _ in
            do {
                try await Task.sleep(for: .seconds(30))
                return n
            } catch {
                await suivi.annule()
                return nil
            }
        }
    }
    file.annuler()
    #expect(file.vide)
    #expect(file.prochain() == nil)
    try? await Task.sleep(for: .milliseconds(200))
    #expect(await suivi.nombreAnnules() == 3)
}

@Test func apresAnnulationLaFileRepartPropre() async {
    let file = FileVocale<String>(enVol: 2)
    file.ajouter("ancien") { t in
        try? await Task.sleep(for: .seconds(30))
        return t
    }
    file.annuler()
    file.ajouter("neuf") { t in t }
    guard let morceau = file.prochain() else {
        Issue.record("un morceau était attendu après annulation")
        return
    }
    #expect(morceau.texte == "neuf")
    #expect(await morceau.audio.value == "neuf")
}
