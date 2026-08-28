#if canImport(SwiftUI)
import Foundation
import Observation
import VigieNoyau

/// Tout ce que l'écran des machines sait, et la façon dont il l'apprend.
///
/// Séparé des vues à dessein : c'est ici que vit la règle du domaine — le
/// miroir d'abord, le réseau ensuite, et les métriques **à la demande**.
@MainActor @Observable
public final class ReleveParc {

    /// Au-delà de cet âge, entrer sur l'écran vaut demande de relevé.
    ///
    /// `☠` Le compromis du domaine. `/machines/metriques` fait un aller-retour
    /// PAR machine, jusqu'à Cloudflare pour le VPS : la sonder en boucle comme
    /// le fait la webapp (3 s) coûte de la batterie toute la journée pour un
    /// chiffre qu'on regarde quelques secondes. Mais arriver sur l'écran et n'y
    /// trouver qu'un relevé d'hier serait pire. Une minute tranche les deux.
    public static let metriquesPerimeesApresS: TimeInterval = 60

    // MARK: Parc
    public private(set) var machines: [MachineApi] = []
    public private(set) var metriques: [String: MetriquesMachineApi] = [:]
    public private(set) var equipes: [String: [MissionApi]] = [:]
    public private(set) var equipesParCompte: [String: [MissionApi]] = [:]

    // MARK: Quotas
    public private(set) var comptes: [AccountApi] = []
    public private(set) var synthese = SyntheseQuotas.depuis([])

    // MARK: Poste de travail
    public private(set) var posteEnLigne: Bool?
    /// `GET /health` : ce que le control plane, lui, croit du parc. Distinct de
    /// `posteEnLigne`, qui vient du websocket du serveur de sessions.
    public private(set) var sante: SanteApi?
    public private(set) var claudeEnCours: Bool?
    public private(set) var comptesClaude: [CompteClaudeApi] = []
    public private(set) var config: ConfigApi?

    // MARK: Dates — chacune sa section, jamais un horodatage global
    public private(set) var parcReleveA: Date?
    public private(set) var metriquesReleveA: Date?
    public private(set) var comptesReleveA: Date?
    public private(set) var posteReleveA: Date?

    // MARK: Marche en cours
    public private(set) var enCours = false
    public private(set) var metriquesEnCours = false
    public internal(set) var reveilEnCours = false
    public private(set) var dernierEchec: String?
    /// Message du registre quand le PC est absent : la donnée est vraie, datée.
    public private(set) var mentionDatee: String?

    public init() {}

    /// Rien de connu, rien de daté : le seul cas qui mérite un squelette.
    public var premierRemplissage: Bool {
        machines.isEmpty && comptes.isEmpty && parcReleveA == nil && comptesReleveA == nil
    }

    public var mentionParc: String { ChargeMachines.mention(machines: machines) }

    /// Le verdict croisé des deux sources — voir `EtatChaine`.
    public var etatChaine: EtatChaine {
        EtatChaine.lire(sante: sante, posteJoignable: posteEnLigne)
    }

    public func equipesDe(_ machine: String) -> [MissionApi] { equipes[machine] ?? [] }

    public func metriquesDe(_ machine: String) -> MetriquesHote? { metriques[machine]?.metriques }

    // MARK: - Miroir

    /// Le miroir AVANT le réseau : l'écran s'ouvre plein, daté, en une frame.
    public func ouvrir(miroir: DepotMiroir) async {
        if let cache = await miroir.lire([MachineApi].self, .machines) {
            machines = cache.valeur
            parcReleveA = cache.releveA
        }
        if let cache = await miroir.lire([MetriquesMachineApi].self, .metriquesMachines) {
            rangerMetriques(cache.valeur, a: cache.releveA)
        }
        if let cache = await miroir.lire([MissionApi].self, .missions) {
            rangerEquipes(cache.valeur)
        }
        if let cache = await miroir.lire([AccountApi].self, .comptes) {
            rangerComptes(cache.valeur, a: cache.releveA)
        }
        if let cache = await miroir.lire(SanteApi.self, .sante) {
            sante = cache.valeur
        }
        await ouvrirPoste(miroir: miroir)
    }

    private func ouvrirPoste(miroir: DepotMiroir) async {
        if let cache = await miroir.lire(StatutPosteApi.self, .statutPoste) {
            posteEnLigne = cache.valeur.pcOnline
            claudeEnCours = cache.valeur.claudeRunning
            posteReleveA = cache.releveA
        }
        if let cache = await miroir.lire(ComptesClaudeApi.self, .comptesClaude) {
            comptesClaude = cache.valeur.accounts ?? []
        }
        if let cache = await miroir.lire(ConfigApi.self, .configPoste) {
            config = cache.valeur
        }
    }

    // MARK: - Rangement

    private func rangerMetriques(_ liste: [MetriquesMachineApi], a instant: Date) {
        metriques = Dictionary(liste.map { ($0.id, $0) }, uniquingKeysWith: { _, dernier in dernier })
        metriquesReleveA = instant
    }

    private func rangerEquipes(_ missions: [MissionApi]) {
        equipes = ChargeMachines.equipesParMachine(missions)
        equipesParCompte = ChargeMachines.equipesParCompte(missions)
    }

    private func rangerComptes(_ liste: [AccountApi], a instant: Date) {
        comptes = liste
        synthese = SyntheseQuotas.depuis(liste)
        comptesReleveA = instant
    }

    // MARK: - Relevé

    /// Le lot complet. Séquentiel et non parallèle : quatre requêtes lancées
    /// ensemble à travers un tunnel Cloudflare depuis un téléphone se gênent
    /// plus qu'elles ne s'accélèrent, et brouillent les traces.
    public func relever(client: ClientPi, forcerMetriques: Bool = false) async {
        guard !enCours else { return }
        enCours = true
        dernierEchec = nil
        mentionDatee = nil
        await lireSante(client)
        await lireMachines(client)
        await lireMissions(client)
        await lireComptes(client)
        await lirePoste(client)
        enCours = false
        if forcerMetriques || metriquesPerimees {
            await releverMetriques(client: client)
        }
    }

    public var metriquesPerimees: Bool {
        guard let metriquesReleveA else { return true }
        return Fraicheur.age(depuis: metriquesReleveA) > Self.metriquesPerimeesApresS
    }

    /// `☠` La seule route du domaine qui coûte cher. Jamais appelée par la
    /// minuterie : seulement à l'ouverture d'un écran périmé et sur geste.
    public func releverMetriques(client: ClientPi) async {
        guard !metriquesEnCours else { return }
        metriquesEnCours = true
        let lecture = await client.lire(
            [MetriquesMachineApi].self, Route.metriquesMachines, memoriser: .metriquesMachines
        )
        if let charge = lecture.charge { rangerMetriques(charge, a: Date()) }
        noter(lecture)
        metriquesEnCours = false
    }

    // MARK: - Une route, une méthode

    /// `☠` Un échec ici ne se dit PAS en `dernierEchec` : `/health` est la
    /// première requête du lot, et si elle tombe les quatre suivantes tomberont
    /// pareil. Le message reviendrait cinq fois pour une seule panne. On perd
    /// simplement le verdict, ce que `.inconnu` dit à sa place.
    private func lireSante(_ client: ClientPi) async {
        sante = try? await client.lireNu(SanteApi.self, Route.sante, memoriser: .sante).get()
    }

    private func lireMachines(_ client: ClientPi) async {
        let lecture = await client.lire([MachineApi].self, Route.machines, memoriser: .machines)
        if let charge = lecture.charge {
            machines = charge
            parcReleveA = Date()
        }
        noter(lecture)
    }

    private func lireMissions(_ client: ClientPi) async {
        let lecture = await client.lire([MissionApi].self, Route.missions, memoriser: .missions)
        if let charge = lecture.charge { rangerEquipes(charge) }
        noter(lecture)
    }

    private func lireComptes(_ client: ClientPi) async {
        let lecture = await client.lire([AccountApi].self, Route.comptes, memoriser: .comptes)
        if let charge = lecture.charge { rangerComptes(charge, a: Date()) }
        noter(lecture)
    }

    /// Trois routes natives du poste, dont deux ne servent qu'une fois par
    /// session : la configuration ne change pas, on ne la redemande pas.
    private func lirePoste(_ client: ClientPi) async {
        let statut = await client.lirePoste(StatutPosteApi.self, Route.statutPoste, memoriser: .statutPoste)
        posteEnLigne = statut.posteEnLigne
        claudeEnCours = statut.charge?.claudeRunning
        posteReleveA = Date()
        if let erreur = statut.echec { dernierEchec = erreur.message }
        guard statut.posteEnLigne == true else { return }
        let comptes = await client.lirePoste(
            ComptesClaudeApi.self, Route.comptesClaude, memoriser: .comptesClaude
        )
        if let charge = comptes.charge { comptesClaude = charge.accounts ?? [] }
        if config == nil {
            config = await client.lireNu(ConfigApi.self, Route.configuration, memoriser: .configPoste).valeur
        }
    }

    /// Une panne se dit une fois, en clair ; un PC absent n'est pas une panne.
    private func noter<Charge: Decodable & Sendable>(_ lecture: LectureApi<Charge>) {
        switch lecture {
        case .fraiche:
            return
        case .datee(_, let message):
            mentionDatee = message ?? "Machine de travail absente — relevés du registre, datés."
        case .echec(let erreur):
            dernierEchec = erreur.message
        }
    }

    // MARK: - Retour des ordres

    func appliquerStatutPoste(enLigne: Bool?, claude: Bool?) {
        posteEnLigne = enLigne
        claudeEnCours = claude
        posteReleveA = Date()
    }

    func appliquerComptesClaude(_ liste: [CompteClaudeApi]) {
        comptesClaude = liste
    }

    func signaler(_ message: String) {
        dernierEchec = message
    }
}
#endif
