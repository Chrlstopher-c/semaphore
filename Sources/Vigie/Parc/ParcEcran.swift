#if canImport(SwiftUI)
import Foundation
import SwiftUI
import VigieNoyau

/// Le parc : toutes les équipes, groupées par état ou par projet.
///
/// `☠` `state` est décodé TEL QUEL, jamais recalculé : recroiser les deux
/// machines à états rejouerait la panne #30. Un état inconnu tombe dans
/// « Autres états » plutôt que d'être filtré — la liste est ouverte côté
/// serveur, et une équipe disparue serait invisible.
public struct ParcEcran: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir

    @State private var missions: [MissionApi] = []
    @State private var groupePar: GroupementParc = .etat
    @State private var releveA: Date?
    @State private var refus: ErreurApi?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            entete
            corps
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Teinte.fond)
        .task { await ouvrir() }
        .cadencePar("parc") { await battre() }
        .navigationDestination(for: RouteParc.self) { route in
            destination(route).toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder private func destination(_ route: RouteParc) -> some View {
        switch route {
        case .equipe(let identifiant):
            EquipeEcran(identifiant: identifiant)
        case .sousAgent(let mission, let agent):
            SousAgentEcran(mission: mission, agent: agent)
        }
    }

    private var entete: some View {
        EnTeteEcran("Parc", releveA: releveA) {
            bascule
        }
    }

    /// Par état pour savoir ce qui réclame, par projet pour savoir où en est
    /// un chantier : deux lectures du même parc, une bascule.
    private var bascule: some View {
        Button {
            withAnimation(Elan.pose) {
                groupePar = groupePar == .etat ? .projet : .etat
            }
        } label: {
            Image(systemName: groupePar == .etat ? "circle.grid.2x2.fill" : "folder.fill")
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.allureIcone)
        .foregroundStyle(Teinte.encreDouce)
        .sensoryFeedback(Haptique.selection, trigger: groupePar)
        .accessibilityLabel(groupePar == .etat ? "Grouper par projet" : "Grouper par état")
    }

    // MARK: - Corps

    private var corps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Trame.section) {
                if let refus, refus.genre != .transport, !missions.isEmpty {
                    BandeauNote(refus.message, ton: .vigilance)
                }
                contenu
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.bottom, Trame.section)
        }
        .scrollIndicators(.hidden)
        .refreshable { await battre() }
    }

    @ViewBuilder private var contenu: some View {
        if !missions.isEmpty {
            Text(TriParc.resume(missions))
                .mention()
                .foregroundStyle(Teinte.encreTernie)
            ForEach(groupes) { groupe in
                section(groupe)
            }
        } else if releveA == nil && refus == nil {
            ForEach(0..<3, id: \.self) { rang in
                Panneau { SilhouetteAttente() }.entreeEnScene(rang: rang)
            }
        } else if let refus, refus.genre != .transport {
            BandeauNote(refus.message, ton: .danger)
        } else {
            EtatCalme(
                symbole: "square.stack.3d.up.fill",
                titre: "Aucune équipe",
                explication: "Le harness n'a aucune équipe en registre."
            )
        }
    }

    private var groupes: [GroupeParc] {
        switch groupePar {
        case .etat: return TriParc.groupes(missions)
        case .projet: return GroupementProjet.groupes(missions)
        }
    }

    private func section(_ groupe: GroupeParc) -> some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection(groupe.titre) {
                Sceau("\(groupe.missions.count)", ton: groupe.id == "arbitrage" ? .attention : .neutre)
            }
            ForEach(Array(groupe.missions.enumerated()), id: \.element.id) { rang, mission in
                NavigationLink(value: RouteParc.equipe(mission.id)) {
                    CarteEquipe(mission: mission)
                }
                .buttonStyle(.allureCarte)
                .entreeEnScene(rang: rang)
            }
        }
    }

    // MARK: - Relevés

    private func ouvrir() async {
        guard let cache = await miroir.lire([MissionApi].self, .missions) else { return }
        missions = cache.valeur
        releveA = cache.releveA
    }

    @MainActor private func battre() async {
        let lecture = await client.lire([MissionApi].self, Route.missions, memoriser: .missions)
        if let charge = lecture.charge {
            missions = charge
            releveA = Date()
        }
        refus = lecture.erreur
    }
}

/// Par état ou par projet : deux raisons de changer, une bascule.
enum GroupementParc: String, CaseIterable, Identifiable {
    case etat
    case projet

    var id: String { rawValue }
}
#endif
