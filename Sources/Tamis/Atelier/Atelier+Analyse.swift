// La boucle d'analyse Vision : les photos pas encore vues, de la plus ancienne à
// la plus récente (le regroupeur exige l'ordre chronologique). Reprise là où on
// s'était arrêté : le carnet retient tout ce qui est passé.
#if canImport(SwiftUI) && canImport(Photos)
import Foundation
import TamisNoyau

extension Atelier {
    /// Photos restant à analyser.
    var restantes: [Cliche] {
        cliches.filter { $0.media == .photo && $0.date != nil && !carnet.analyses.contains($0.id) }
    }

    func lancerAnalyse() {
        guard tacheAnalyse == nil else { return }
        let lot = restantes.sorted(by: Tamisage.chronologique)
        guard !lot.isEmpty else {
            analyse = .finie
            return
        }
        analyse = .enCours(fait: 0, total: lot.count)
        tacheAnalyse = Task { await analyser(lot) }
    }

    func suspendreAnalyse() {
        tacheAnalyse?.cancel()
    }

    /// `☠` Vision ne tourne pas en arrière-plan (le GPU y est refusé) : chaque
    /// photo échouerait. On suspend en partant et on reprend en revenant.
    func sommeil() {
        guard tacheAnalyse != nil else { return }
        analyseEnSommeil = true
        suspendreAnalyse()
    }

    func reveil() {
        guard analyseEnSommeil else { return }
        analyseEnSommeil = false
        Task {
            // La tâche suspendue doit d'abord s'éteindre, sinon le garde de
            // `lancerAnalyse` refuse de repartir.
            while tacheAnalyse != nil { try? await Task.sleep(for: .milliseconds(100)) }
            lancerAnalyse()
        }
    }

    private func analyser(_ lot: [Cliche]) async {
        var regroupeur = Regroupeur()
        for (rang, cliche) in lot.enumerated() {
            if Task.isCancelled { break }
            let lecture = await Analyseur.analyser(cliche.id)
            consigner(lecture, cliche, &regroupeur)
            analyse = .enCours(fait: rang + 1, total: lot.count)
            if rang % 250 == 249 {
                sauverCarnet()
                recalculer()
            }
        }
        let complete = !Task.isCancelled
        tacheAnalyse = nil
        analyse = complete ? .finie : .repos
        sauverCarnet()
        recalculer()
        Journal.note("analyse \(complete ? "terminée" : "suspendue")")
    }

    /// `lecture` nulle : l'image n'existe pas en local, la photo est marquée vue
    /// pour ne pas la reprendre à chaque passe. Lecture vide : Vision a échoué
    /// (arrière-plan, mémoire) — la photo reste à analyser.
    private func consigner(_ lecture: Lecture?, _ cliche: Cliche, _ regroupeur: inout Regroupeur) {
        guard let lecture else {
            carnet.analyses.insert(cliche.id)
            return
        }
        guard lecture.qualite != nil || lecture.vecteur != nil else { return }
        carnet.analyses.insert(cliche.id)
        if let qualite = lecture.qualite { carnet.qualites[cliche.id] = qualite }
        if let brut = lecture.vecteur, let date = cliche.date,
           let empreinte = Empreinte(id: cliche.id, date: date, brut: brut) {
            carnet.paires.append(contentsOf: regroupeur.ajouter(empreinte))
        }
    }
}
#endif
