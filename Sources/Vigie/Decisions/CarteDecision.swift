// La carte d'une décision : le rail coloré sur la tranche, l'engagement au
// même rang que le titre, et les deux gestes sous le pouce.
//
// `☠` H-61 — autorisation ÉCLAIRÉE : le droit réel (`acces`) n'est jamais
// replié. Une équipe annoncée « lecture seule » recevait les mêmes outils
// qu'une équipe de modification tant que ce champ n'était pas montré.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct CarteDecision: View {
    let decision: Decision
    let rang: Int
    /// Un geste est en vol quelque part dans la file : les boutons s'éteignent.
    let occupee: Bool
    /// Confirmée tranchée par le serveur : tamponnée jusqu'au relevé suivant.
    let tranchee: Bool
    let conduite: ConduiteApresConflit?
    let accorder: () async -> Void
    let refuser: () async -> Void

    var body: some View {
        Panneau(rail: tranchee ? .sain : ton) {
            VStack(alignment: .leading, spacing: Trame.element) {
                entete
                corpsDeLaCarte
                if let conduite { BlocConduite(conduite: conduite) }
                pied
            }
        }
        .opacity(tranchee ? 0.65 : 1)
        .animation(Elan.pose, value: tranchee)
        .entreeEnScene(rang: rang)
        .sensoryFeedback(Haptique.reussite, trigger: tranchee) { _, faite in faite }
    }

    // MARK: - Composition

    private var entete: some View {
        HStack(spacing: Trame.serre) {
            Sceau(decision.genre.titre, ton: ton)
            Text(portee)
                .mention()
                .foregroundStyle(Teinte.encreTernie)
            Spacer(minLength: 0)
            Text(Lisible.heure(millisecondes))
                .donneePetite()
                .foregroundStyle(Teinte.encreTernie)
        }
    }

    @ViewBuilder private var corpsDeLaCarte: some View {
        switch decision {
        case .mandat(let proposition): DetailMandat(proposition: proposition)
        case .rallonge(let demande): DetailRallonge(demande: demande)
        case .arbitrage(let mission): DetailArbitrage(mission: mission)
        }
    }

    @ViewBuilder private var pied: some View {
        if tranchee {
            tampon
        } else if conduite?.reArmable ?? true {
            gestes
        }
    }

    /// Deux boutons, jamais un geste ambigu, et jamais de confirmation
    /// intermédiaire : la garde biométrique EST la confirmation.
    private var gestes: some View {
        HStack(spacing: Trame.element) {
            Button(libelleRefus) { Task { await refuser() } }
                .buttonStyle(.allureDanger)
                .disabled(occupee)
            Button(libelleAccord) { Task { await accorder() } }
                .buttonStyle(.allureAccent)
                .disabled(occupee)
        }
        .opacity(occupee ? 0.5 : 1)
        .animation(Elan.vif, value: occupee)
    }

    /// Le tampon d'une carte tranchée : elle reste en place jusqu'au relevé
    /// suivant — c'est le serveur qui vide la file, jamais l'écran.
    private var tampon: some View {
        HStack(spacing: Trame.serre) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Tranchée — la file se relève au prochain battement")
                .note()
        }
        .foregroundStyle(Teinte.sain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Trame.serre)
        .background(Ton.sain.voile, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: - Libellés

    private var libelleAccord: String {
        switch decision {
        case .mandat: return "Autoriser"
        case .rallonge: return "Accorder"
        case .arbitrage: return "Laisser poursuivre"
        }
    }

    private var libelleRefus: String {
        switch decision {
        case .mandat, .rallonge: return "Refuser"
        case .arbitrage: return "Arrêter l'équipe"
        }
    }

    /// Ce que trancher ENGAGE, en trois mots — la ligne qui empêche de
    /// confondre les trois circuits.
    private var portee: String {
        switch decision {
        case .mandat: return "démarre une équipe"
        case .rallonge: return "n'ouvre aucune équipe"
        case .arbitrage: return "équipe en boucle"
        }
    }

    private var ton: Ton {
        switch decision.genre {
        case .mandat: return .attention
        case .arbitrage: return .danger
        case .rallonge: return .veille
        }
    }

    private var millisecondes: Int {
        switch decision {
        case .arbitrage(let mission): return mission.inspection.lastAt ?? 0
        case .mandat(let proposition): return proposition.creeA
        case .rallonge(let demande): return demande.creeA
        }
    }
}

/// Le refus du serveur, mot pour mot, et la conduite à tenir — jamais l'un
/// sans l'autre : le message dit ce qui s'est passé, jamais où aller.
private struct BlocConduite: View {
    let conduite: ConduiteApresConflit

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            HStack(spacing: Trame.serre) {
                Sceau(conduite.titre, ton: ton)
                Spacer(minLength: 0)
                if let sceau = conduite.sceau {
                    Text(sceau)
                        .mention()
                        .foregroundStyle(ton.teinte)
                }
            }
            Text(conduite.motifServeur)
                .donneePetite()
                .foregroundStyle(Teinte.encre)
            Text(conduite.conduite)
                .mention()
                .foregroundStyle(Teinte.encreDouce)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Trame.element)
        .background(ton.voile, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var ton: Ton {
        switch conduite.etat {
        case .danger: return .danger
        case .vigilance: return .vigilance
        case .sain: return .sain
        case .accent: return .attention
        case .neutre: return .neutre
        }
    }
}
#endif
