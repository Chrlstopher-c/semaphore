#if canImport(SwiftUI)
import Foundation
import SwiftUI
import VigieNoyau

/// Le détail d'une équipe : son état, ses gestes de pilotage, l'instruction
/// qu'on lui glisse, sa consommation, son dépôt, ses sous-agents et son fil.
///
/// `☠` Les gestes ne sont pas optimistes : après une écriture, on relit la
/// mission. Un bouton qui repeint l'écran tout seul finit par afficher une
/// équipe en pause qui tourne encore.
struct EquipeEcran: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir

    let identifiant: String

    @State private var mission: MissionApi?
    @State private var releveA: Date?
    @State private var refus: ErreurApi?
    @State private var gesteEnCours: String?

    var body: some View {
        VStack(spacing: 0) {
            EnTeteEcran(mission?.project ?? "Équipe", releveA: releveA, retour: true)
            corps
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Teinte.fond)
        .task { await ouvrir() }
        .cadencePar("equipe.\(identifiant)") { await battre() }
        .rendLeClavier()
    }

    @ViewBuilder private var corps: some View {
        if let mission {
            ScrollView {
                VStack(alignment: .leading, spacing: Trame.section) {
                    if let refus, refus.genre != .transport {
                        BandeauNote(refus.message, ton: .vigilance)
                    }
                    enTete(mission)
                    GestesEquipe(mission: mission, enCours: $gesteEnCours, apres: { await battre() })
                    InstructionEquipe(mission: mission, apres: { await battre() })
                    SectionConsommation(mission: mission)
                    SectionDepot(mission: mission)
                    SectionSousAgents(mission: mission)
                    SectionMandat(mission: mission)
                    sectionFil(mission)
                }
                .padding(.horizontal, Trame.ecran)
                .padding(.bottom, Trame.section)
            }
            .scrollIndicators(.hidden)
            .refreshable { await battre() }
        } else if let refus {
            BandeauNote(refus.message, ton: .danger)
                .padding(Trame.ecran)
            Spacer(minLength: 0)
        } else {
            Panneau { SilhouetteAttente() }
                .padding(Trame.ecran)
            Spacer(minLength: 0)
        }
    }

    // MARK: - En-tête

    private func enTete(_ mission: MissionApi) -> some View {
        let etat = EtatEquipe(mission.state)
        return VStack(alignment: .leading, spacing: Trame.serre) {
            Text(mission.title)
                .titreFeuille()
                .foregroundStyle(Teinte.encre)
            HStack(spacing: Trame.serre) {
                PointVeille(ton: ton(etat), vivant: etat.respire)
                Sceau(etat.libelle, ton: ton(etat))
                if let anciennete = EtatEquipe.anciennete(mission) {
                    Text(anciennete)
                        .donneePetite()
                        .foregroundStyle(Teinte.encreTernie)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: Trame.serre) {
                if let machine = mission.machine { PuceDonnee(machine) }
                PuceDonnee(mission.model)
                PuceDonnee(mission.team)
                PuceDonnee("relances \(mission.retries)")
            }
        }
    }

    private func ton(_ etat: EtatEquipe) -> Ton {
        switch etat.ton {
        case .attente: return .attention
        case .actif: return .sain
        case .veille: return .veille
        case .alerte: return .danger
        case .clos, .neutre: return .neutre
        }
    }

    /// `☠` Le fil est vide sur la LISTE et rempli sur le DÉTAIL : il n'existe
    /// qu'ici. Les identités des lignes sont synthétisées par le noyau —
    /// sans elles, chaque relevé refermerait les blocs dépliés.
    @ViewBuilder private func sectionFil(_ mission: MissionApi) -> some View {
        if !mission.feed.isEmpty {
            VStack(alignment: .leading, spacing: Trame.element) {
                TeteDeSection("Fil de l'équipe")
                VueFilMission(
                    segments: SegmentationMission.segmenter(mission.feed),
                    sousAgents: mission.subagents,
                    missionId: mission.id,
                    partiel: mission.partial
                )
            }
        }
    }

    // MARK: - Relevés

    private func ouvrir() async {
        guard let cache = await miroir.lire(MissionApi.self, .mission(identifiant)) else { return }
        mission = cache.valeur
        releveA = cache.releveA
    }

    @MainActor private func battre() async {
        let lecture = await client.lire(
            MissionApi.self, Route.mission(identifiant), memoriser: .mission(identifiant)
        )
        if let charge = lecture.charge {
            mission = charge
            releveA = Date()
        }
        refus = lecture.erreur
    }
}
#endif
