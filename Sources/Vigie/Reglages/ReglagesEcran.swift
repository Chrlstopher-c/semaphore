#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Réglages : serveur, orchestrateur, canal d'alerte, à propos. Poussé depuis
/// le portillon de l'en-tête du Quart — on y va une fois par semaine.
///
/// `☠` Régime `.aLaDemande` : le catalogue de modèles et les comptes Claude
/// ne bougent pas toutes les quatre secondes. Un aller-retour à l'ouverture,
/// un autre au tiré-pour-rafraîchir — jamais une boucle.
public struct ReglagesEcran: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir

    @State private var modeles: [ModeleApi] = []
    @State private var comptes: [CompteClaudeApi] = []
    @State private var avis: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            EnTeteEcran("Réglages", retour: true)
            corps
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Teinte.fond)
        .rendLeClavier()
        .avisFugace($avis)
        .task { await depuisMiroir() }
        .cadencePar("reglages", regime: .aLaDemande) { await rafraichir() }
    }

    private var corps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Trame.section) {
                SectionServeur(avis: poser)
                SectionOrchestrateur(modeles: modeles, comptes: comptes, bascule: bascule)
                SectionAlerte()
                SectionAPropos()
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.bottom, Trame.section)
        }
        .scrollIndicators(.hidden)
        .refreshable { await rafraichir() }
    }

    @MainActor private func poser(_ message: String) {
        avis = message
    }

    // MARK: - Relevés

    @MainActor private func depuisMiroir() async {
        if let donnee = await miroir.lire([ModeleApi].self, .modeles) {
            modeles = donnee.valeur
        }
        if let donnee = await miroir.lire(ComptesClaudeApi.self, .comptesClaude) {
            comptes = donnee.valeur.accounts ?? []
        }
    }

    @MainActor private func rafraichir() async {
        let lecture = await client.lire([ModeleApi].self, Route.modeles, memoriser: .modeles)
        if let charge = lecture.charge { modeles = charge }
        switch await client.lirePoste(ComptesClaudeApi.self, Route.comptesClaude, memoriser: .comptesClaude) {
        case .fraiche(let charge):
            comptes = charge.accounts ?? []
        case .pcAbsent, .refus, .echec:
            break // le poste éteint garde la dernière liste connue, datée
        }
    }

    // MARK: - Gestes

    /// `☠` Une bascule REDÉMARRE les sessions tmux qui tournaient : le dire,
    /// sinon un travail en cours semble avoir disparu tout seul.
    @MainActor private func bascule(_ compte: CompteClaudeApi) async {
        let corps: CorpsJSON = ["account": .texte(compte.id)]
        switch await client.ordonner(BasculeCompteApi.self, Route.basculerCompteClaude, corps) {
        case .fraiche(let accuse):
            let relancees = accuse.restartedSessions ?? []
            if accuse.status == "already_active" {
                poser("Déjà le compte actif")
            } else if relancees.isEmpty {
                poser("Compte basculé sur \(compte.label)")
            } else {
                poser("Compte basculé — sessions relancées : \(relancees.joined(separator: ", "))")
            }
            await rafraichir()
        case .pcAbsent(let message), .refus(let message):
            poser(message)
        case .echec(let erreur):
            poser(erreur.message)
        }
    }
}
#endif
