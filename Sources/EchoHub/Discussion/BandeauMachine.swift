// Le bandeau d'état de la machine, posé entre le fil et le composeur.
//
// Il ne se lève que quand quelque chose empêcherait une réponse : machine
// silencieuse, aucun modèle chargé, modèle en chargement ou en échec. Le dire
// AVANT que Chris tape vaut mieux qu'un échec après l'envoi — et le bandeau ne
// bloque rien : l'envoi reste possible, c'est le serveur qui tranche.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct BandeauMachine: View {
    @Environment(Salon.self) private var salon
    @State private var sonde = false

    var body: some View {
        if let raison = RaisonBandeau(statut: salon.statut) {
            Button(action: sonder) { contenu(raison) }
                .buttonStyle(.appui)
                .disabled(sonde)
                .transition(.scene)
        }
    }

    private func contenu(_ raison: RaisonBandeau) -> some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            HStack(spacing: Trame.serre) {
                Sceau(raison.libelle, symbole: raison.symbole).ton(raison.ton)
                Spacer(minLength: 0)
                if sonde {
                    ProgressView().tint(Teinte.encreDouce).controlSize(.small)
                } else {
                    Text("Vérifier").legende().foregroundStyle(Teinte.accent)
                }
            }
            if let detail = raison.detail {
                Text(detail).legende().foregroundStyle(Teinte.encreDouce).lineLimit(2)
            }
        }
        .padding(.horizontal, Trame.ecran)
        .padding(.vertical, Trame.serre)
        .contentShape(.rect)
    }

    private func sonder() {
        guard !sonde else { return }
        sonde = true
        Task {
            // Sonde le moteur MAINTENANT, pas l'état mémorisé : un moteur mort
            // n'apparaît pas dans `/etat`, qui continue de le dire prêt.
            await salon.sonderMoteur()
            sonde = false
        }
    }
}

/// Les raisons de lever le bandeau. `nil` = modèle prêt, rien à dire.
private enum RaisonBandeau {
    /// Le premier relevé n'a pas encore répondu. Un « injoignable » affiché
    /// pendant cette seconde serait un mensonge à chaque lancement.
    case releveEnCours
    /// Le relevé a échoué, et on sait pourquoi. C'est le cas que le ton neutre
    /// d'avant rendait indiscernable du précédent — dans le sens rassurant.
    case injoignable(String)
    case aucunModele, chargement, echec

    init?(statut: EtatChargement<StatutInference>) {
        switch statut {
        case .chargement, .vide: self = .releveEnCours
        case .echec(let raison): self = .injoignable(raison)
        case .pret(let releve):
            switch releve.etat {
            case .pret: return nil
            case .inactif: self = .aucunModele
            case .enCours: self = .chargement
            case .echoue: self = .echec
            }
        }
    }

    var libelle: String {
        switch self {
        case .releveEnCours: return "Relevé de la machine…"
        case .injoignable: return "Machine injoignable"
        case .aucunModele: return "Aucun modèle chargé"
        case .chargement: return "Modèle en chargement"
        case .echec: return "Modèle en échec"
        }
    }

    /// La cause, quand elle est connue. Un bandeau qui dit « injoignable » sans
    /// dire pourquoi envoie chercher au mauvais endroit — voir le jeton refusé.
    var detail: String? {
        if case .injoignable(let raison) = self { return raison }
        return nil
    }

    var symbole: String {
        switch self {
        case .releveEnCours: return "hourglass"
        case .injoignable: return "antenna.radiowaves.left.and.right.slash"
        case .aucunModele: return "cpu"
        case .chargement: return "hourglass"
        case .echec: return "exclamationmark.triangle.fill"
        }
    }

    var ton: Ton {
        switch self {
        case .releveEnCours: return .neutre
        case .injoignable: return .panne
        case .aucunModele: return .neutre
        case .chargement: return .actif
        case .echec: return .panne
        }
    }
}
#endif
