// L'atelier : l'état entier du monde Tamis. L'inventaire de la photothèque, les
// décisions de Chris, ce que l'analyse a appris, et les vues qui en dérivent
// (strates, pistes). Les écrans lisent ici et n'écrivent que par ses intentions.
//
// `☠` Les calculs dérivés (strates, pistes) tournent hors du fil principal et
// sont REMPLACÉS d'un bloc : sur 35 000 éléments, les recalculer dans `body`
// figerait chaque glissé du tri rapide.
#if canImport(SwiftUI) && canImport(Photos)
import Foundation
import Observation
import TamisNoyau

@MainActor
@Observable
final class Atelier {
    enum Etat: Equatable { case attente, refuse, inventaire, pret }

    private(set) var etat: Etat = .attente
    private(set) var accesLimite = false
    private(set) var cliches: [Cliche] = []
    private(set) var index: [String: Cliche] = [:]
    private(set) var decisions = Decisions()
    var carnet = Carnet()
    var reglage = ReglagePistes() { didSet { recalculer() } }

    private(set) var strates: [Strate] = []
    private(set) var releves: [Releve] = []
    /// Éléments dont le poids reste à mesurer.
    private(set) var aPeser = 0
    var analyse = EtatAnalyse.repos
    var tacheAnalyse: Task<Void, Never>?
    /// Vrai si l'analyse a été suspendue par le passage en arrière-plan, et
    /// doit reprendre au retour.
    @ObservationIgnored var analyseEnSommeil = false
    /// Le dernier compte rendu de suppression, affiché dans le panier.
    var bilan: Bilan?

    @ObservationIgnored private var tacheCalcul: Task<Void, Never>?
    @ObservationIgnored let dossier: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (base ?? FileManager.default.temporaryDirectory).appendingPathComponent("Tamis", isDirectory: true)
    }()

    init() {}

    // MARK: - Démarrage

    /// Idempotent. Rejoué après un refus : l'accès a pu être accordé depuis
    /// Réglages entre-temps.
    func demarrer() async {
        guard etat == .attente || etat == .refuse else { return }
        switch await Inventaire.autoriser() {
        case .refuse:
            etat = .refuse
            return
        case .limite:
            accesLimite = true
        case .complet:
            break
        }
        etat = .inventaire
        lireCoffre()
        await inventorier()
        etat = .pret
        await peser()
    }

    /// Relit la photothèque : après une suppression faite dans Photos, ou au
    /// retour dans le monde.
    func actualiser() async {
        guard etat == .pret else { return }
        await inventorier()
        await peser()
    }

    private func inventorier() async {
        let fiches = await Task.detached(priority: .userInitiated) { Inventaire.lister() }.value
        let existants = Set(fiches.map(\.id))
        decisions.restreindre(a: existants)
        carnet.oublier(Set(carnet.analyses).subtracting(existants))
        installer(fiches.map { fiche in
            var f = fiche
            f.poids = carnet.poids[f.id]
            return f
        })
    }

    private func installer(_ fiches: [Cliche]) {
        cliches = fiches
        index = Dictionary(fiches.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        aPeser = fiches.lazy.filter { $0.poids == nil }.count
        recalculer()
    }

    /// Mesure les poids manquants par lots, en rendant la main entre deux : les
    /// strates se remplissent sous les yeux au lieu d'attendre la fin.
    private func peser() async {
        let manquants = cliches.filter { $0.poids == nil }.map(\.id)
        for debut in stride(from: 0, to: manquants.count, by: 1_500) {
            let lot = Array(manquants[debut..<min(debut + 1_500, manquants.count)])
            let poids = await Task.detached(priority: .utility) { Inventaire.peser(lot) }.value
            carnet.poids.merge(poids) { _, nouveau in nouveau }
            installer(cliches.map { c in
                var f = c
                if f.poids == nil { f.poids = poids[f.id] }
                return f
            })
        }
        sauverCarnet()
    }

    // MARK: - Décisions

    func mettreAuPanier(_ ids: some Sequence<String>) { decider { $0.mettreAuPanier(ids) } }
    func garder(_ ids: some Sequence<String>) { decider { $0.garder(ids) } }
    func oublier(_ ids: some Sequence<String>) { decider { $0.oublier(ids) } }

    func basculerPanier(_ id: String) {
        if decisions.panier.contains(id) { oublier([id]) } else { mettreAuPanier([id]) }
    }

    private func decider(_ geste: (inout Decisions) -> Void) {
        geste(&decisions)
        sauverDecisions()
        recalculer()
    }

    var panier: [Cliche] {
        decisions.panier.compactMap { index[$0] }.sorted(by: Tamisage.chronologique)
    }

    var poidsTotal: Int64 { cliches.poidsTotal }
    var poidsPanier: Int64 { decisions.panier.reduce(0) { $0 + (index[$1]?.poids ?? 0) } }

    // MARK: - Dérivés

    func recalculer() {
        tacheCalcul?.cancel()
        let fiches = cliches, panier = decisions.panier, gardes = decisions.gardes
        let pistage = Pistage(
            cliches: fiches, qualites: carnet.qualites, paires: carnet.paires, gardes: gardes, reglage: reglage
        )
        tacheCalcul = Task {
            let calcul = await Task.detached(priority: .userInitiated) {
                (Stratigraphie.calculer(fiches, panier: panier), pistage.releves())
            }.value
            guard !Task.isCancelled else { return }
            strates = calcul.0
            releves = calcul.1
        }
    }

    // MARK: - Coffre

    private func lireCoffre() {
        do {
            decisions = try Coffre.lire(Decisions.self, "decisions.json", dans: dossier) ?? Decisions()
            carnet = try Coffre.lire(Carnet.self, "carnet.json", dans: dossier) ?? Carnet()
        } catch {
            Journal.echec("lecture du coffre : \(error.localizedDescription)")
        }
    }

    func sauverDecisions() {
        do { try Coffre.ecrire(decisions, "decisions.json", dans: dossier) } catch {
            Journal.echec("écriture des décisions : \(error.localizedDescription)")
        }
    }

    func sauverCarnet() {
        do { try Coffre.ecrire(carnet, "carnet.json", dans: dossier) } catch {
            Journal.echec("écriture du carnet : \(error.localizedDescription)")
        }
    }

    /// Retire des éléments supprimés de tout l'état local.
    func retirer(_ ids: Set<String>) {
        decisions.oublier(ids)
        carnet.oublier(ids)
        installer(cliches.filter { !ids.contains($0.id) })
        sauverDecisions()
        sauverCarnet()
    }
}

/// Où en est l'analyse Vision.
enum EtatAnalyse: Equatable {
    case repos
    case enCours(fait: Int, total: Int)
    case finie
}

/// Le compte rendu d'une suppression.
struct Bilan: Equatable {
    let nombre: Int
    let poids: Int64
    let echec: String?
}
#endif
