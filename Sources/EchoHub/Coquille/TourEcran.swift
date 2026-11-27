// L'état de la tour, vu du Pi : éteinte, en cours d'allumage, EchoHub arrêté, prêt.
// Tant que la tour n'est pas prête, cet écran couvre l'app : rien d'autre n'y servirait.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

@MainActor @Observable
final class SuiviTour {
    private(set) var phase: PhaseTour?
    private(set) var erreur: String?
    private(set) var actionEnCours = false
    private let client: ClientEchoHub
    private var boucle: Task<Void, Never>?

    init(client: ClientEchoHub) { self.client = client }

    /// Sonde toutes les 3 s tant que quelque chose change (allumage, démarrage), 15 s sinon.
    func suivre() {
        boucle?.cancel()
        boucle = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.rafraichir()
                let transitoire = self.phase == .allumage || self.phase == .demarrage
                try? await Task.sleep(for: .seconds(transitoire ? 3 : 15))
            }
        }
    }

    func arreter() { boucle?.cancel() }

    func rafraichir() async {
        do {
            phase = PhaseTour.depuis(try await client.etatTour())
            erreur = nil
        } catch ErreurRelais.annule {
        } catch {
            erreur = (error as? ErreurRelais)?.localizedDescription ?? error.localizedDescription
        }
    }

    func allumer() async { await agir { try await self.client.reveillerTour() } }
    func demarrerEchoHub() async { await agir { try await self.client.demarrerEchoHub() } }

    private func agir(_ action: @escaping () async throws -> Void) async {
        actionEnCours = true
        defer { actionEnCours = false }
        do {
            try await action()
            await rafraichir()
            suivre()
        } catch {
            erreur = (error as? ErreurRelais)?.localizedDescription ?? error.localizedDescription
        }
    }
}

struct TourEcran: View {
    let suivi: SuiviTour

    var body: some View {
        VStack(spacing: Trame.bloc) {
            Spacer()
            Image(systemName: symbole)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(couleur)
                .symbolEffect(.pulse, isActive: enAttente)
            VStack(spacing: Trame.serre) {
                Text(titre).font(Typo.titreEcran).foregroundStyle(Teinte.encre)
                Text(detail).font(Typo.corps).foregroundStyle(Teinte.encreDouce)
                    .multilineTextAlignment(.center)
            }
            if let erreur = suivi.erreur {
                Text(erreur).font(Typo.legende).foregroundStyle(Teinte.panne)
                    .multilineTextAlignment(.center)
            }
            bouton
            Spacer()
        }
        .padding(.horizontal, Trame.ecran)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Teinte.fond)
        .animation(Elan.normal, value: suivi.phase)
        .refreshable { await suivi.rafraichir() }
    }

    @ViewBuilder private var bouton: some View {
        switch suivi.phase {
        case .eteinte?:
            action("Allumer la tour", symbole: "power") { await suivi.allumer() }
        case .echohubArrete?, .demarrageEchoue?:
            action("Démarrer EchoHub", symbole: "play.fill") { await suivi.demarrerEchoHub() }
        default:
            EmptyView()
        }
    }

    private func action(_ libelle: String, symbole: String, _ faire: @escaping () async -> Void) -> some View {
        Button {
            Task { await faire() }
        } label: {
            Label(libelle, systemImage: symbole)
                .font(Typo.entete)
                .frame(maxWidth: .infinity, minHeight: Trame.cible)
        }
        .buttonStyle(.borderedProminent)
        .tint(Teinte.accent)
        .disabled(suivi.actionEnCours)
        .sensoryFeedback(Retour.engage, trigger: suivi.actionEnCours)
    }

    private var enAttente: Bool {
        suivi.phase == nil || suivi.phase == .allumage || suivi.phase == .demarrage || suivi.actionEnCours
    }

    private var symbole: String {
        switch suivi.phase {
        case .eteinte?: return "power"
        case .allumage?: return "power.circle"
        case .echohubArrete?, .demarrageEchoue?: return "server.rack"
        case .demarrage?: return "arrow.triangle.2.circlepath"
        case .prete?: return "checkmark.circle"
        case nil: return "antenna.radiowaves.left.and.right"
        }
    }

    private var couleur: Color {
        switch suivi.phase {
        case .demarrageEchoue?: return Teinte.panne
        case .prete?: return Teinte.ok
        case .allumage?, .demarrage?: return Teinte.accent
        default: return Teinte.encreDouce
        }
    }

    private var titre: String {
        switch suivi.phase {
        case .eteinte?: return "La tour est éteinte"
        case .allumage?: return "La tour s'allume…"
        case .echohubArrete?: return "EchoHub est arrêté"
        case .demarrage?: return "EchoHub démarre…"
        case .demarrageEchoue?: return "Le démarrage a échoué"
        case .prete?: return "EchoHub est prêt"
        case nil: return "Recherche de la tour…"
        }
    }

    private var detail: String {
        switch suivi.phase {
        case .eteinte?: return "Le Pi peut la réveiller à distance."
        case .allumage?: return "Une à deux minutes, le temps du démarrage."
        case .echohubArrete?: return "La tour est allumée, l'app EchoHub ne répond pas encore."
        case .demarrage?: return "Lancement des services sur la tour."
        case .demarrageEchoue?: return "Réessaie ; si ça persiste, le journal est sur la tour."
        case .prete(let modele)?: return modele.map { "Modèle chargé : \($0)" } ?? "Aucun modèle chargé."
        case nil: return "Interrogation du relais."
        }
    }
}
#endif
