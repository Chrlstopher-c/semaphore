// Le poste de travail : son état et son réveil. La bascule de compte Claude
// vit aux Réglages — un seul endroit par geste.
//
// `☠` Routes NATIVES de pi-web : elles répondent 200 avec `pc_online: false`
// quand le PC dort. Un 200 n'y vaut pas succès — c'est `posteEnLigne` qu'on
// lit, jamais le code HTTP.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct SectionPoste: View {
    @Environment(\.clientPi) private var client
    let releve: ReleveParc

    @State private var retour: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Poste de travail") {
                Sceau(libelleEtat, ton: ton)
            }
            Panneau {
                VStack(alignment: .leading, spacing: Trame.element) {
                    lignes
                    if releve.posteEnLigne != true { boutonReveil }
                    if let retour {
                        Text(retour)
                            .note()
                            .foregroundStyle(Teinte.encreDouce)
                            .transition(.opacity)
                    }
                }
            }
        }
        .animation(Elan.pose, value: retour)
    }

    private var lignes: some View {
        VStack(spacing: 0) {
            LigneCle("État", valeur: libelleEtat, teinteValeur: ton.teinte)
            LigneCle(
                "Claude Code",
                valeur: releve.claudeEnCours == true ? "en cours" : "à l'arrêt",
                derniere: releve.config == nil
            )
            if let config = releve.config {
                LigneCle("Hôte", valeur: config.pcHost, derniere: true)
            }
        }
    }

    /// `☠` Le réveil est un ordre différé : le paquet magique part du Pi, sans
    /// réponse du poste. « Envoyé » ne veut pas dire « allumé » — seul le
    /// relevé suivant le dira, quelques dizaines de secondes plus tard.
    private var boutonReveil: some View {
        Button(releve.reveilEnCours ? "Paquet en route…" : "Réveiller le poste") {
            Task { await reveiller() }
        }
        .buttonStyle(.allureDouce)
        .disabled(releve.reveilEnCours)
    }

    private func reveiller() async {
        releve.reveilEnCours = true
        defer { releve.reveilEnCours = false }
        let reponse = await client.ecrireNu(ReveilApi.self, Route.reveillerPoste)
        retour = reponse.echec?.message
            ?? "Paquet de réveil parti du Pi — le poste répondra dans les prochaines dizaines de secondes."
    }

    // MARK: - Formes

    private var libelleEtat: String {
        switch releve.posteEnLigne {
        case .some(true): return "en ligne"
        case .some(false): return "éteint"
        case nil: return "inconnu"
        }
    }

    /// Éteint n'est pas en panne : c'est le régime nominal des nuits.
    private var ton: Ton {
        switch releve.posteEnLigne {
        case .some(true): return .sain
        case .some(false): return .veille
        case nil: return .neutre
        }
    }
}
#endif
