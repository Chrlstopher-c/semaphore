#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Les domaines de Vigie.
///
/// `☠` **C'est le SEUL point de couplage entre les domaines.** Aucun écran n'a
/// le droit d'en nommer un autre autrement qu'à travers ce type.
///
/// La refonte d'août 2026 fusionne l'atterrissage et les décisions : `quart`
/// et `decisions` mènent à la même pièce. Le défaut fondateur de la webapp
/// était une décision noyée ; la réponse est une seule pièce d'entrée où la
/// file se tranche directement, pas un accueil qui renvoie ailleurs.
public enum Domaine: String, CaseIterable, Identifiable, Hashable, Sendable {
    case quart
    case decisions
    case fil
    case parc
    case machines
    case terminal
    /// Portillon (roue dentée de l'en-tête du Quart), pas un onglet.
    case reglages
    /// La cloche de l'en-tête du Quart, et les notifications y renvoient.
    case alerte

    public var id: String { rawValue }

    /// La barre : cinq entrées. Réglages et Alerte s'atteignent depuis
    /// l'en-tête du Quart — on y va trop rarement pour un cinquième d'écran.
    public static let barre: [Domaine] = [.quart, .fil, .parc, .machines, .terminal]

    public var titre: String {
        switch self {
        case .quart: return "Quart"
        case .decisions: return "Décisions"
        case .fil: return "Fil"
        case .parc: return "Parc"
        case .machines: return "Machines"
        case .terminal: return "Terminal"
        case .reglages: return "Réglages"
        case .alerte: return "Alerte"
        }
    }

    /// Symboles volontairement anciens (iOS 14 au plus tard) : un symbole
    /// absent se rend en carré vide, sans erreur ni avertissement.
    public var symbole: String {
        switch self {
        case .quart: return "moon.stars.fill"
        case .decisions: return "hand.raised.fill"
        case .fil: return "bubble.left.and.bubble.right.fill"
        case .parc: return "square.stack.3d.up.fill"
        case .machines: return "desktopcomputer"
        case .terminal: return "terminal.fill"
        case .reglages: return "gearshape.fill"
        case .alerte: return "bell.badge.fill"
        }
    }

    /// La vue racine. Chaque racine s'instancie SANS argument : tout vient de
    /// l'environnement (`\.clientPi`, `\.miroir`, `Cadence`, `Liaison`).
    @MainActor @ViewBuilder
    public var racine: some View {
        switch self {
        case .quart, .decisions: QuartEcran()
        case .fil: FilEcran()
        case .parc: ParcEcran()
        case .machines: MachinesEcran()
        case .terminal: TerminalEcran()
        case .reglages: ReglagesEcran()
        case .alerte: AlerteEcran()
        }
    }
}

/// Ce que la coquille sait du parc sans le sonder elle-même : les compteurs de
/// badge, tenus à jour par les écrans qui lisent déjà ces routes. Aucun réseau
/// ici — un badge n'achète pas un aller-retour de plus.
@MainActor @Observable
public final class TableauDeVeille {
    public var decisionsEnAttente = 0
    public var notificationsNonLues = 0

    public init() {}
}

/// La coquille : cinq piles de navigation vivantes, la barre de veille en bas.
///
/// `☠` Les piles vivent en permanence — changer d'onglet ne rejette jamais la
/// position de lecture. Conséquence : `onAppear` se déclenche pour les cinq,
/// d'où `\.ecranVisible`, qui empêche quatre écrans invisibles de sonder le Pi.
public struct Coquille: View {
    @Environment(Cablage.self) private var cablage
    @Environment(Cadence.self) private var cadence
    @Environment(Liaison.self) private var liaison
    @Environment(\.scenePhase) private var phaseScene
    @Environment(\.clientPi) private var client

    @State private var onglet: Domaine = .quart
    @State private var cheminQuart = NavigationPath()
    @State private var cheminFil = NavigationPath()
    @State private var veille = TableauDeVeille()
    @State private var amorce = false
    @State private var action = ActionRecue.partage

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            contenu
            BarreDeVeille(onglet: $onglet, decisions: veille.decisionsEnAttente)
        }
        .background(Teinte.fond.ignoresSafeArea())
        .environment(veille)
        .preferredColorScheme(.dark)
        .task { await amorcer() }
        .onChange(of: phaseScene) { _, phase in reagirALaScene(phase) }
        .onChange(of: action.ouverture) { _, demande in suivre(demande) }
        .fullScreenCover(isPresented: sessionAOuvrir) { EcranConnexion() }
    }

    private var contenu: some View {
        ZStack {
            ForEach(Domaine.barre) { candidat in
                pile(candidat)
                    .opacity(candidat == onglet ? 1 : 0)
                    .allowsHitTesting(candidat == onglet)
                    .environment(\.ecranVisible, candidat == onglet)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private func pile(_ domaine: Domaine) -> some View {
        switch domaine {
        case .quart:
            NavigationStack(path: $cheminQuart) { racineNue(domaine) }
        case .fil:
            NavigationStack(path: $cheminFil) { racineNue(domaine) }
        default:
            NavigationStack { racineNue(domaine) }
        }
    }

    private func racineNue(_ domaine: Domaine) -> some View {
        domaine.racine
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Domaine.self) { pousse in
                pousse.racine.toolbar(.hidden, for: .navigationBar)
            }
    }

    /// La connexion s'impose dès que la session est requise : sans elle, rien
    /// n'est lisible, il n'y a donc rien d'autre à montrer.
    private var sessionAOuvrir: Binding<Bool> {
        Binding(
            get: { amorce && liaison.regime == .sessionRequise },
            set: { _ in }
        )
    }

    private func amorcer() async {
        guard !amorce else { return }
        await cablage.amorcer()
        let ouverte = await client.sessionOuverte
        if !ouverte { liaison.exigerSession() }
        amorce = true
    }

    /// Une notification touchée mène à sa pièce. Les décisions vivent au
    /// Quart ; Réglages et Alerte se poussent sur sa pile.
    private func suivre(_ demande: OuvertureDemandee?) {
        guard let demande else { return }
        withAnimation(Elan.pose) {
            switch demande.domaine {
            case .quart, .decisions:
                onglet = .quart
            case .reglages, .alerte:
                onglet = .quart
                cheminQuart.append(demande.domaine)
            case .fil:
                onglet = .fil
                if let fil = demande.fil {
                    cheminFil.append(RouteFil.conversation(fil, ""))
                }
            default:
                onglet = demande.domaine
            }
        }
        action.ouverture = nil
    }

    private func reagirALaScene(_ phase: ScenePhase) {
        cadence.scene(phase)
        // Le rattrapage d'ouverture : le canal 2, déterministe — il rend compte
        // de tout ce qui s'est passé pendant que Vigie ne tournait pas.
        if phase == .active, amorce {
            Task { await CentreAlerte.partage.sonder(origine: .ouverture) }
        }
        guard phase != .active else { return }
        // Dernier instant garanti avant une mise à mort : le miroir doit être
        // sur le disque, pas dans un regroupement d'écriture en attente.
        Task { [miroir = cablage.miroir] in await miroir.ecrireMaintenant() }
    }
}
#endif
