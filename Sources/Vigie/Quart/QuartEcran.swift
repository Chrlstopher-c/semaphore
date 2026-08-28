#if canImport(SwiftUI)
import Foundation
import SwiftUI
import VigieNoyau

/// La pièce d'entrée : la file de ce que Chris seul peut trancher, actionnable
/// sur place, et le pouls du parc à voix basse au-dessus.
///
/// `☠` Quart et Décisions sont UNE pièce depuis la refonte : le défaut
/// fondateur de la webapp était un mandat noyé dans un accueil qui renvoyait
/// ailleurs. Ici, la carte se tranche là où elle se lit. Les trois circuits
/// (mandats, rallonges, arbitrages) gardent leurs objets, libellés et routes.
public struct QuartEcran: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir
    @Environment(TableauDeVeille.self) private var veille

    @State private var propositions: [PropositionApi] = []
    @State private var rallonges: [RallongeApi] = []
    @State private var missions: [MissionApi] = []
    @State private var machines: [MachineApi] = []
    @State private var comptes: [AccountApi] = []
    @State private var jauges: JaugesApi?
    @State private var nonLues = 0
    @State private var releveA: Date?
    @State private var refus: ErreurApi?
    @State private var arbitrage: Arbitrage?
    @State private var tour = 0

    /// `☠` Le pouls et le badge de cloche ne battent qu'un tour sur cinq —
    /// vingt secondes. Sept routes toutes les quatre secondes à travers le
    /// tunnel, c'est la dérive de la SPA qu'on est venu corriger ; la file,
    /// elle, bat à chaque tour parce qu'elle est la raison de la pièce.
    private static let toursParReleveDuParc = 5

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            entete
            corps
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Teinte.fond)
        .task { await relireLeMiroir() }
        .cadencePar("quart") { await battre() }
        .sensoryFeedback(Haptique.alerte, trigger: file.count) { ancien, nouveau in
            nouveau > ancien
        }
    }

    // MARK: - En-tête

    private var entete: some View {
        EnTeteEcran("Vigie", releveA: releveA) {
            cloche
            NavigationLink(value: Domaine.reglages) {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.allureIcone)
            .foregroundStyle(Teinte.encreDouce)
            .accessibilityLabel("Réglages")
        }
    }

    /// La cloche : l'état du canal d'alerte et les faits du parc, badgés par
    /// les non-lues. Le seul autre orange de l'écran, et il est mérité.
    private var cloche: some View {
        NavigationLink(value: Domaine.alerte) {
            Image(systemName: nonLues > 0 ? "bell.badge.fill" : "bell.fill")
                .symbolRenderingMode(nonLues > 0 ? .palette : .monochrome)
                .foregroundStyle(nonLues > 0 ? Teinte.accent : Teinte.encreDouce, Teinte.encreDouce)
        }
        .buttonStyle(.allureIcone)
        .accessibilityLabel(nonLues > 0 ? "\(nonLues) notifications non lues" : "Alerte")
    }

    // MARK: - Corps

    private var corps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Trame.section) {
                BandeauPouls(pouls: pouls)
                sectionFile
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.bottom, Trame.section)
        }
        .scrollIndicators(.hidden)
        .refreshable { await battre() }
    }

    private var pouls: PoulsDuParc {
        PoulsDuParc(missions: missions, machines: machines, comptes: comptes, jauges: jauges)
    }

    /// Les cartes tranchées restent affichées, tamponnées, jusqu'au relevé
    /// suivant : les faire disparaître à la seconde du clic rendrait deux
    /// gestes rapides indiscernables.
    private var file: [Decision] {
        let mandats = propositions.filter { $0.statut == .enAttente }.map(Decision.mandat)
        let demandes = rallonges.filter { $0.statut == .enAttente }.map(Decision.rallonge)
        let arbitrages = missions.filter(\.inspection.attendArbitrage).map(Decision.arbitrage)
        return (mandats + demandes + arbitrages).trieesParUrgence()
    }

    private var sectionFile: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("À trancher") {
                if !file.isEmpty {
                    Sceau("\(file.count)", ton: .attention)
                }
            }
            if let refus, refus.genre != .transport {
                BandeauNote(refus.message, ton: .vigilance)
            }
            contenuDeLaFile
        }
    }

    @ViewBuilder private var contenuDeLaFile: some View {
        if let arbitrage, !file.isEmpty {
            VStack(spacing: Trame.element) {
                ForEach(Array(file.enumerated()), id: \.element.id) { rang, decision in
                    CarteDecision(
                        decision: decision,
                        rang: rang,
                        occupee: arbitrage.enCours != nil,
                        tranchee: arbitrage.estTranchee(decision),
                        conduite: arbitrage.conduite(pour: decision),
                        accorder: { await trancher { await arbitrage.approuver(decision) } },
                        refuser: { await trancher { await arbitrage.refuser(decision) } }
                    )
                }
            }
        } else if releveA == nil && refus == nil {
            attente
        } else if let refus, file.isEmpty, missions.isEmpty {
            BandeauNote(refus.message, ton: .danger)
        } else {
            EtatCalme(
                symbole: "moon.stars.fill",
                titre: "Rien ne t'attend",
                explication: "Aucun mandat, aucune rallonge, aucun arbitrage. "
                    + "Le parc travaille sans toi."
            )
        }
    }

    /// Des silhouettes, jamais un tourniquet : réservées au tout premier
    /// lancement, avant qu'aucune donnée datée n'existe.
    private var attente: some View {
        VStack(spacing: Trame.element) {
            ForEach(0..<2, id: \.self) { rang in
                Panneau { SilhouetteAttente(lignes: [0.35, 0.9, 0.55]) }
                    .entreeEnScene(rang: rang)
            }
        }
    }

    // MARK: - Relevés

    @MainActor private func relireLeMiroir() async {
        if arbitrage == nil { arbitrage = Arbitrage(client: client) }
        await depuisMiroir([PropositionApi].self, .propositions) { propositions = $0 }
        await depuisMiroir([RallongeApi].self, .rallonges) { rallonges = $0 }
        await depuisMiroir([MissionApi].self, .missions) { missions = $0 }
        await depuisMiroir([MachineApi].self, .machines) { machines = $0 }
        await depuisMiroir([AccountApi].self, .comptes) { comptes = $0 }
        await depuisMiroir(JaugesApi.self, .jauges) { jauges = $0 }
        await depuisMiroir(ListeNotificationsApi.self, .notifications) { nonLues = $0.unread }
        publierLesBadges()
    }

    /// Un geste tranché est suivi d'un relevé immédiat : c'est le serveur qui
    /// dit ce qui reste dans la file, jamais une déduction locale.
    private func trancher(_ geste: () async -> Void) async {
        await geste()
        await battreLaFile()
    }

    @MainActor private func battre() async {
        tour &+= 1
        await battreLaFile()
        if tour % Self.toursParReleveDuParc == 1, refus == nil {
            refus = await lireLePouls()
        }
        if refus == nil { releveA = Date() }
        publierLesBadges()
    }

    @MainActor private func battreLaFile() async {
        let mandats = await lire([PropositionApi].self, Route.propositions, .propositions) {
            propositions = $0
        }
        let demandes = await lire([RallongeApi].self, Route.rallonges, .rallonges) { rallonges = $0 }
        let equipes = await lire([MissionApi].self, Route.missions, .missions) { missions = $0 }
        refus = mandats ?? demandes ?? equipes
    }

    @MainActor private func lireLePouls() async -> ErreurApi? {
        let parc = await lire([MachineApi].self, Route.machines, .machines) { machines = $0 }
        let quotas = await lire([AccountApi].self, Route.comptes, .comptes) { comptes = $0 }
        let mesures = await lire(JaugesApi.self, Route.jauges, .jauges) { jauges = $0 }
        let faits = await lire(ListeNotificationsApi.self, Route.notifications, .notifications) {
            nonLues = $0.unread
        }
        return parc ?? quotas ?? mesures ?? faits
    }

    private func publierLesBadges() {
        veille.decisionsEnAttente = file.count
        veille.notificationsNonLues = nonLues
    }

    /// `☠` Les lectures sont en SÉRIE, jamais en parallèle : des requêtes
    /// simultanées dans le tunnel Cloudflare se gênent plus qu'elles ne
    /// s'accélèrent.
    @MainActor private func lire<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        _ chemin: String,
        _ cle: CleMiroir,
        _ appliquer: (Charge) -> Void
    ) async -> ErreurApi? {
        let lecture = await client.lire(type, chemin, memoriser: cle)
        if let charge = lecture.charge { appliquer(charge) }
        return lecture.erreur
    }

    @MainActor private func depuisMiroir<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        _ cle: CleMiroir,
        _ appliquer: (Charge) -> Void
    ) async {
        guard let donnee = await miroir.lire(type, cle) else { return }
        appliquer(donnee.valeur)
        // La plus ancienne des sections relues : c'est elle qui dit ce que
        // vaut l'écran pris dans son ensemble.
        releveA = min(releveA ?? donnee.releveA, donnee.releveA)
    }
}
#endif
