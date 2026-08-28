// Le fil d'un sous-agent — la route du contrat qui n'avait aucune surface :
// `GET /missions/{id}/agents/{agentId}` rend l'agent avec son fil rempli.
#if canImport(SwiftUI)
import Foundation
import SwiftUI
import VigieNoyau

struct SousAgentEcran: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir

    let mission: String
    let agent: String

    @State private var detail: SubagentApi?
    @State private var releveA: Date?
    @State private var refus: ErreurApi?

    var body: some View {
        VStack(spacing: 0) {
            EnTeteEcran(detail?.name ?? "Sous-agent", releveA: releveA, retour: true)
            corps
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Teinte.fond)
        .task { await ouvrir() }
        .cadencePar("sousagent.\(mission).\(agent)") { await battre() }
    }

    @ViewBuilder private var corps: some View {
        if let detail {
            ScrollView {
                VStack(alignment: .leading, spacing: Trame.section) {
                    if let refus, refus.genre != .transport {
                        BandeauNote(refus.message, ton: .vigilance)
                    }
                    fiche(detail)
                    fil(detail)
                }
                .padding(.horizontal, Trame.ecran)
                .padding(.bottom, Trame.section)
            }
            .scrollIndicators(.hidden)
            .refreshable { await battre() }
        } else if let refus {
            BandeauNote(refus.message, ton: .danger).padding(Trame.ecran)
            Spacer(minLength: 0)
        } else {
            Panneau { SilhouetteAttente() }.padding(Trame.ecran)
            Spacer(minLength: 0)
        }
    }

    private func fiche(_ detail: SubagentApi) -> some View {
        Panneau {
            VStack(spacing: 0) {
                LigneCle("Rôle", valeur: detail.role.isEmpty ? "—" : detail.role)
                LigneCle("Statut", valeur: libelle(detail.status), teinteValeur: ton(detail.status).teinte)
                LigneCleLongue(
                    "Dernière action",
                    valeur: detail.action.isEmpty ? "—" : detail.action,
                    derniere: true
                )
            }
        }
    }

    @ViewBuilder private func fil(_ detail: SubagentApi) -> some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Fil du sous-agent")
            if detail.feedUnavailable {
                // `☠` L'agent EXISTE (le disque le prouve) mais rien de lisible
                // n'a été relevé : jamais masqué, jamais rempli d'un texte inventé.
                EtatCalme(
                    symbole: "questionmark.folder",
                    titre: "Sans relevé",
                    explication: "Le sous-agent existe, mais rien de lisible n'a pu être "
                        + "relevé sur le disque de la machine.",
                    ton: .neutre
                )
            } else if detail.feed.isEmpty {
                Text("Fil vide pour l'instant.")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            } else {
                VueFilMission(
                    segments: SegmentationMission.segmenter(detail.feed),
                    sousAgents: [],
                    missionId: mission,
                    partiel: nil
                )
            }
        }
    }

    // MARK: - Libellés

    private func libelle(_ statut: StatutSousAgentApi) -> String {
        switch statut {
        case .actif: return "actif"
        case .attente: return "en attente"
        case .termine: return "terminé"
        default: return statut.rawValue
        }
    }

    private func ton(_ statut: StatutSousAgentApi) -> Ton {
        switch statut {
        case .actif: return .sain
        case .attente: return .veille
        default: return .neutre
        }
    }

    // MARK: - Relevés

    private func ouvrir() async {
        guard let cache = await miroir.lire(SubagentApi.self, .sousAgent(mission: mission, agent: agent)) else {
            return
        }
        detail = cache.valeur
        releveA = cache.releveA
    }

    @MainActor private func battre() async {
        let lecture = await client.lire(
            SubagentApi.self,
            Route.sousAgent(mission: mission, agent: agent),
            memoriser: .sousAgent(mission: mission, agent: agent)
        )
        if let charge = lecture.charge {
            detail = charge
            releveA = Date()
        }
        refus = lecture.erreur
    }
}

extension CleMiroir {
    /// Rubrique AJOUTÉE par l'interface (le noyau reste intouché) : le détail
    /// d'un sous-agent, adressé par mission puis agent — deux missions peuvent
    /// porter des agents au même identifiant.
    static func sousAgent(mission: String, agent: String) -> CleMiroir {
        CleMiroir("sousAgent", "\(mission)/\(agent)")
    }
}
#endif
