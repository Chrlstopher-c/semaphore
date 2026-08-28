// Les sections de lecture du détail d'équipe : consommation, dépôt,
// sous-agents, mandat. Chacune dit une chose et la dit mesurée.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct SectionConsommation: View {
    let mission: MissionApi

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Consommation")
            Panneau {
                VStack(alignment: .leading, spacing: Trame.element) {
                    jauge
                    VStack(spacing: 0) {
                        LigneCle("Dépense", valeur: ConsommationEquipe.montant(mission.cost))
                        LigneCle("Prochaine inspection", valeur: prochainSeuil, derniere: true)
                    }
                }
            }
        }
    }

    /// `☠` Sans relevé, la jauge ment : le mot remplace le chiffre.
    @ViewBuilder private var jauge: some View {
        if ConsommationEquipe.mesure(mission.ctxTokens) {
            JaugeFine(
                "Contexte",
                part: Double(mission.ctx) / 100,
                detail: ConsommationEquipe.tokensLisibles(mission.ctxTokens),
                seuilVigilance: 0.5,
                seuilDanger: 0.75
            )
        } else {
            LigneCle("Contexte", valeur: "non mesuré", derniere: true)
        }
    }

    /// `nil` = tous les paliers passés. Une échéance, pas une alerte : aucun
    /// montant n'est mauvais en soi.
    private var prochainSeuil: String {
        guard let seuil = ConsommationEquipe.prochainSeuil(mission.cost) else {
            return "tous les paliers passés"
        }
        return ConsommationEquipe.montant(seuil)
    }
}

struct SectionDepot: View {
    let mission: MissionApi

    private var constat: ConstatDepot { ConstatDepot.lire(mission.git) }

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Dépôt") {
                if constat.travailEnJeu {
                    Sceau("travail en jeu", ton: .vigilance)
                }
            }
            Panneau(rail: constat.travailEnJeu ? .vigilance : nil) {
                VStack(alignment: .leading, spacing: 0) {
                    LigneCle("État", valeur: constat.valeur, teinteValeur: teinteEtat)
                    LigneCle("Branche", valeur: constat.releve?.branche ?? valeurOuTiret(mission.branch))
                    if let commit = constat.releve?.dernierCommit {
                        LigneCle("Dernier commit", valeur: commit)
                    }
                    LigneCle("Worktree", valeur: valeurOuTiret(mission.worktree), derniere: constat.releve == nil)
                    if let releve = constat.releve {
                        // `☠` Toujours daté : un « propre » d'il y a quarante
                        // minutes ne dit rien du dépôt maintenant.
                        LigneCle(
                            "Relevé",
                            valeur: Lisible.heure(releve.a),
                            teinteValeur: Teinte.encreTernie,
                            derniere: true
                        )
                    }
                }
            }
        }
    }

    private var teinteEtat: Color {
        switch constat {
        case .jamaisReleve: return Teinte.encreTernie
        case .propre: return Teinte.sain
        case .travailNonCommite: return Teinte.vigilance
        }
    }

    private func valeurOuTiret(_ texte: String) -> String {
        texte.isEmpty ? "—" : texte
    }
}

/// Les sous-agents : chacun s'ouvre sur son propre fil.
struct SectionSousAgents: View {
    let mission: MissionApi

    var body: some View {
        if !mission.subagents.isEmpty {
            VStack(alignment: .leading, spacing: Trame.element) {
                TeteDeSection("Sous-agents") {
                    Sceau("\(mission.subagents.count)", ton: .neutre)
                }
                VStack(spacing: Trame.serre) {
                    ForEach(mission.subagents) { agent in
                        ligne(agent)
                    }
                }
            }
        }
    }

    private func ligne(_ agent: SubagentApi) -> some View {
        NavigationLink(value: RouteParc.sousAgent(mission.id, agent.id)) {
            Panneau {
                HStack(spacing: Trame.serre) {
                    PointVeille(ton: ton(agent.status), vivant: agent.status == .actif)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.name)
                            .phraseForte()
                            .foregroundStyle(Teinte.encre)
                            .lineLimit(1)
                        // `☠` « sans relevé » n'est pas masqué ni inventé :
                        // l'agent existe, rien de lisible n'a été relevé.
                        Text(agent.feedUnavailable ? "sans relevé" : agent.action)
                            .mention()
                            .foregroundStyle(Teinte.encreTernie)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Sceau(libelle(agent.status), ton: ton(agent.status))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Teinte.encreTernie)
                }
            }
        }
        .buttonStyle(.allureCarte)
    }

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
}

struct SectionMandat: View {
    let mission: MissionApi

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Mandat")
            Panneau {
                VStack(spacing: 0) {
                    LigneCleLongue("But", valeur: lisible(mission.mandate.but))
                    LigneCleLongue("Critère d'arrêt", valeur: lisible(mission.mandate.critere))
                    LigneCle("Compte", valeur: mission.account, derniere: true)
                }
            }
        }
    }

    private func lisible(_ texte: String) -> String {
        texte.isEmpty ? "—" : texte
    }
}
#endif
