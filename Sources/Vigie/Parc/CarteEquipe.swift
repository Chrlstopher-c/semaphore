// La carte d'une équipe : ce qu'elle fait, ce qu'elle consomme, et ce qui
// serait perdu — lisible sans l'ouvrir.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct CarteEquipe: View {
    let mission: MissionApi

    private var etat: EtatEquipe { EtatEquipe(mission.state) }

    var body: some View {
        Panneau(rail: etat.ton == .attente ? .attention : nil) {
            VStack(alignment: .leading, spacing: Trame.serre) {
                entete
                mesures
                if let avertissement = ConstatDepot.lire(mission.git).avertissement {
                    Text(avertissement)
                        .mention()
                        .foregroundStyle(Teinte.vigilance)
                }
            }
        }
    }

    private var entete: some View {
        HStack(alignment: .firstTextBaseline, spacing: Trame.serre) {
            PointVeille(ton: ton, vivant: etat.respire)
            Text(mission.title)
                .phraseForte()
                .foregroundStyle(Teinte.encre)
                .lineLimit(2)
            Spacer(minLength: 0)
            Sceau(etat.libelle, ton: ton)
        }
    }

    private var mesures: some View {
        HStack(spacing: Trame.serre) {
            PuceDonnee(mission.project)
            if let machine = mission.machine { PuceDonnee(machine) }
            PuceDonnee(mission.team)
            Spacer(minLength: 0)
            Text(sousLigne)
                .donneePetite()
                .foregroundStyle(teinteContexte)
        }
    }

    /// `☠` `ctx` sans relevé vaut 0 côté serveur : le mot remplace le chiffre —
    /// « 0 % » se lirait « il reste tout », là où la vérité est « on ne sait
    /// pas », et c'est là-dessus qu'on décide d'un atterrissage.
    private var sousLigne: String {
        let contexte = ConsommationEquipe.mesure(mission.ctxTokens) ? "ctx \(mission.ctx) %" : "ctx —"
        return "\(contexte) · \(ConsommationEquipe.montant(mission.cost))"
    }

    private var teinteContexte: Color {
        switch ConsommationEquipe.tonContexte(mission.ctx) {
        case .alerte: return Teinte.danger
        case .veille: return Teinte.vigilance
        default: return Teinte.encreDouce
        }
    }

    private var ton: Ton {
        switch etat.ton {
        case .attente: return .attention
        case .actif: return .sain
        case .veille: return .veille
        case .alerte: return .danger
        case .clos, .neutre: return .neutre
        }
    }
}
#endif
