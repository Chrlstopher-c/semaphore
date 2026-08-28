#if canImport(SwiftUI)
import Foundation
import Observation
import SwiftUI
import VigieNoyau

/// **La** minuterie de Vigie. Une seule, propriété de la coquille.
///
/// `☠` La SPA fait tourner une dizaine de minuteries de 400 ms à 15 s en
/// parallèle, quel que soit l'onglet regardé. Un navigateur de bureau l'absorbe ;
/// un iPhone XS le paie en batterie et en chaleur toute la journée. Ici, un seul
/// battement, dicté par l'écran visible, suspendu dès que la scène quitte
/// l'avant-plan.
///
/// Le régime effectif est le plus rapide des abonnés ACTIFS. Comme un écran se
/// désabonne en disparaissant, ça revient à « la cadence de ce que Chris
/// regarde », sans qu'aucun domaine ait à connaître les autres.
@MainActor @Observable
public final class Cadence {

    public enum Regime: Int, Sendable, Comparable, CaseIterable {
        /// Jamais battu automatiquement. Les métriques de machines sont ici :
        /// un aller-retour PAR machine, jusqu'à Cloudflare pour le VPS.
        case aLaDemande = 0
        /// 4 s — Quart, Parc, Décisions, fil au repos.
        case repos = 1
        /// 400 ms — un fil en cours de génération. Seul régime où l'écran change
        /// assez vite pour que quelqu'un le regarde vraiment.
        case generation = 2

        public var intervalle: Duration? {
            switch self {
            case .aLaDemande: return nil
            case .repos: return .milliseconds(4000)
            case .generation: return .milliseconds(400)
            }
        }

        public static func < (gauche: Regime, droite: Regime) -> Bool {
            gauche.rawValue < droite.rawValue
        }
    }

    private struct Abonne {
        var regime: Regime
        let battre: @MainActor @Sendable () async -> Void
    }

    private var abonnes: [String: Abonne] = [:]
    private var boucle: Task<Void, Never>?

    /// Le régime réellement appliqué. Observable : un écran peut l'afficher.
    public private(set) var regimeCourant: Regime = .aLaDemande
    /// Faux dès que la scène n'est plus active — plus aucun battement.
    public private(set) var sceneActive = true
    /// Nombre de battements servis depuis le lancement. Diagnostic.
    public private(set) var battements = 0

    public init() {}

    // MARK: - Abonnement

    /// `identifiant` doit être stable pour un écran donné : c'est lui qui permet
    /// de se réabonner sans se dédoubler après une recomposition.
    public func abonner(
        _ identifiant: String,
        regime: Regime = .repos,
        battre: @escaping @MainActor @Sendable () async -> Void
    ) {
        abonnes[identifiant] = Abonne(regime: regime, battre: battre)
        reevaluer()
    }

    public func desabonner(_ identifiant: String) {
        abonnes.removeValue(forKey: identifiant)
        reevaluer()
    }

    /// Change le régime d'un abonné déjà en place — un fil qui se met à générer.
    public func changerRegime(_ identifiant: String, _ regime: Regime) {
        guard var abonne = abonnes[identifiant], abonne.regime != regime else { return }
        abonne.regime = regime
        abonnes[identifiant] = abonne
        reevaluer()
    }

    // MARK: - Battements forcés

    /// Bat un abonné tout de suite, hors cadence. C'est la voie des gestes :
    /// après une approbation de mandat, on ne fait pas attendre quatre secondes.
    public func battreMaintenant(_ identifiant: String) {
        guard let abonne = abonnes[identifiant] else { return }
        Task { @MainActor in await abonne.battre() }
    }

    /// Bat tout le monde. Réservé au retour d'arrière-plan et au geste « tirer
    /// pour rafraîchir ».
    public func battreTout() {
        let tous = abonnes.values.map(\.battre)
        Task { @MainActor in
            for battre in tous { await battre() }
        }
    }

    // MARK: - Cycle de vie de la scène

    public func scene(_ phase: ScenePhase) {
        let active = (phase == .active)
        guard active != sceneActive else { return }
        sceneActive = active
        Trace.info("cadence", active ? "scène active" : "scène en retrait — minuterie suspendue")
        reevaluer()
        if active { battreTout() }
    }

    // MARK: - Moteur

    private func reevaluer() {
        let vise = sceneActive ? (abonnes.values.map(\.regime).max() ?? .aLaDemande) : .aLaDemande
        guard vise != regimeCourant else { return }
        regimeCourant = vise
        boucle?.cancel()
        guard let intervalle = vise.intervalle else {
            boucle = nil
            return
        }
        boucle = Task { @MainActor [weak self] in
            await self?.tourner(intervalle)
        }
    }

    /// Battements en série, jamais en parallèle : un abonné lent doit retarder
    /// le tour suivant, pas empiler des requêtes concurrentes sur le tunnel.
    private func tourner(_ intervalle: Duration) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: intervalle)
            } catch {
                return
            }
            guard sceneActive else { return }
            battements += 1
            for abonne in abonnes.values { await abonne.battre() }
        }
    }
}

// MARK: - Visibilité

/// `☠` Les sept piles de navigation de la coquille vivent en permanence, sinon
/// changer d'onglet rejetterait la position de lecture. Conséquence : `onAppear`
/// se déclenche pour les sept, y compris celles à opacité nulle. Sans ce drapeau,
/// sept écrans s'abonneraient à la minuterie et sonderaient le Pi en parallèle —
/// exactement le défaut de la SPA qu'on est venu corriger.
private struct CleEcranVisible: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Vrai quand le domaine englobant est celui que Chris regarde.
    public var ecranVisible: Bool {
        get { self[CleEcranVisible.self] }
        set { self[CleEcranVisible.self] = newValue }
    }
}

// MARK: - Raccord d'écran

private struct AbonnementCadence: ViewModifier {
    @Environment(Cadence.self) private var cadence
    @Environment(\.ecranVisible) private var visible
    let identifiant: String
    let regime: Cadence.Regime
    let battre: @MainActor @Sendable () async -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { if visible { brancher() } }
            .onDisappear { cadence.desabonner(identifiant) }
            .onChange(of: visible) { _, montre in
                if montre { brancher() } else { cadence.desabonner(identifiant) }
            }
            .onChange(of: regime) { _, nouveau in cadence.changerRegime(identifiant, nouveau) }
    }

    /// S'abonner ET battre tout de suite : arriver sur un écran ne doit jamais
    /// coûter quatre secondes d'attente avant le premier relevé.
    private func brancher() {
        cadence.abonner(identifiant, regime: regime, battre: battre)
        cadence.battreMaintenant(identifiant)
    }
}

extension View {
    /// Branche un écran sur la minuterie unique, et l'en débranche dès qu'il
    /// n'est plus regardé. À préférer systématiquement à un `Timer` local :
    /// c'est la seule chose qui empêche de retomber dans les dix minuteries de
    /// la SPA. Le premier battement part à l'affichage, sans attendre le tour.
    public func cadencePar(
        _ identifiant: String,
        regime: Cadence.Regime = .repos,
        battre: @escaping @MainActor @Sendable () async -> Void
    ) -> some View {
        modifier(AbonnementCadence(identifiant: identifiant, regime: regime, battre: battre))
    }
}
#endif
