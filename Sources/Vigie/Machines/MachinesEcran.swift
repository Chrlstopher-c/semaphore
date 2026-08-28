#if canImport(SwiftUI)
import Foundation
import SwiftUI
import VigieNoyau

/// Le parc matériel : machines de travail, quotas Claude, poste de travail.
///
/// `☠` Les métriques ne battent PAS avec la minuterie : un aller-retour PAR
/// machine, jusqu'à Cloudflare pour le VPS. À l'ouverture si le relevé est
/// périmé, et sur geste — jamais en boucle.
public struct MachinesEcran: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir

    @State private var releve = ReleveParc()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            entete
            corps
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Teinte.fond)
        .task { await ouvrir() }
        .cadencePar("machines") { await releve.relever(client: client) }
    }

    private var entete: some View {
        EnTeteEcran("Machines", releveA: releve.parcReleveA) {
            Button {
                Task { await releve.releverMetriques(client: client) }
            } label: {
                Image(systemName: "gauge")
            }
            .buttonStyle(.allureIcone)
            .foregroundStyle(releve.metriquesEnCours ? Teinte.encreTernie : Teinte.encreDouce)
            .disabled(releve.metriquesEnCours)
            .accessibilityLabel("Relever les métriques")
        }
    }

    private var corps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Trame.section) {
                avertissements
                if releve.premierRemplissage {
                    attente
                } else {
                    sectionMachines
                    sectionQuotas
                    SectionPoste(releve: releve)
                }
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.bottom, Trame.section)
        }
        .scrollIndicators(.hidden)
        .refreshable { await releve.relever(client: client, forcerMetriques: true) }
    }

    @ViewBuilder private var avertissements: some View {
        // La chaîne d'abord : un control plane muet explique tous les vides
        // affichés en dessous, alors qu'un échec de lecture ne dit pas pourquoi.
        if let alerte = releve.etatChaine.alerte {
            BandeauNote(alerte, ton: .danger)
        }
        if let echec = releve.dernierEchec {
            BandeauNote(echec, ton: .danger)
        } else if let mention = releve.mentionDatee {
            // Un PC absent n'est pas une panne : la donnée est vraie, datée.
            BandeauNote(mention, ton: .veille)
        }
    }

    // MARK: - Machines

    private var sectionMachines: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Machines") {
                HStack(spacing: Trame.serre) {
                    Text(releve.mentionParc)
                        .donneeMinuscule()
                        .foregroundStyle(Teinte.encreTernie)
                    if let mesure = releve.metriquesReleveA {
                        Text("· mesures")
                            .donneeMinuscule()
                            .foregroundStyle(Teinte.encreTernie)
                        MentionFraicheur(mesure)
                    }
                }
            }
            ForEach(Array(releve.machines.enumerated()), id: \.element.id) { rang, machine in
                CarteMachine(
                    machine: machine,
                    metriques: releve.metriquesDe(machine.id),
                    equipes: releve.equipesDe(machine.id).count
                )
                .entreeEnScene(rang: rang)
            }
        }
    }

    // MARK: - Quotas

    private var sectionQuotas: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Comptes Claude") {
                Sceau(mentionQuotas, ton: releve.synthese.parcSature ? .danger : .neutre)
            }
            if releve.comptes.isEmpty {
                Text("Aucun compte connu du harness.")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            } else {
                ForEach(Array(releve.comptes.enumerated()), id: \.element.id) { rang, compte in
                    CarteCompte(
                        compte: compte,
                        equipes: releve.equipesParCompte[compte.id]?.count ?? 0
                    )
                    .entreeEnScene(rang: rang)
                }
            }
        }
    }

    private var mentionQuotas: String {
        let synthese = releve.synthese
        guard !synthese.aucunCompte else { return "aucun" }
        guard synthese.satures > 0 else { return "\(synthese.total) disponibles" }
        return "\(synthese.satures)/\(synthese.total) saturés"
    }

    private var attente: some View {
        VStack(spacing: Trame.element) {
            ForEach(0..<3, id: \.self) { rang in
                Panneau { SilhouetteAttente(lignes: [0.4, 0.8]) }
                    .entreeEnScene(rang: rang)
            }
        }
    }

    private func ouvrir() async {
        await releve.ouvrir(miroir: miroir)
        await releve.relever(client: client)
    }
}
#endif
