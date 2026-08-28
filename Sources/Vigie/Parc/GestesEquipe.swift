// Le pilotage d'une équipe : pause, reprise, interruption, inspection, fin.
//
// `☠` Deux distinctions que l'écran doit rendre évidentes :
//   · INTERROMPRE coupe le tour en vol, la session reste vivante et le
//     contexte est préservé — réversible.
//   · TERMINER ferme l'équipe. Le travail non commité part avec, et c'est
//     irréversible : geste armé + Face ID, jamais un simple bouton.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct GestesEquipe: View {
    @Environment(\.clientPi) private var client

    let mission: MissionApi
    @Binding var enCours: String?
    let apres: () async -> Void

    @State private var retour: String?

    private var etat: EtatEquipe { EtatEquipe(mission.state) }

    var body: some View {
        // Une équipe morte n'écoute plus rien : aucun bouton ne ment.
        if etat.pilotable {
            VStack(alignment: .leading, spacing: Trame.element) {
                TeteDeSection("Pilotage")
                rangeeReversible
                BoutonArme(libelleFin, libelleArme: "Relâche pour terminer") {
                    Task { await terminer() }
                }
                .disabled(enCours != nil)
                if let retour {
                    // L'effet est le mot du serveur : lui seul sait ce qui
                    // s'est réellement passé (« instruction retenue », etc.).
                    Text(retour)
                        .note()
                        .foregroundStyle(Teinte.encreDouce)
                        .transition(.opacity)
                }
            }
            .animation(Elan.pose, value: retour)
        }
    }

    private var rangeeReversible: some View {
        HStack(spacing: Trame.serre) {
            if etat.enPause {
                Button("Reprendre") { lancer("reprise", Route.reprendreMission(mission.id)) }
                    .buttonStyle(.allurePuce)
            } else {
                Button("Mettre en pause") { lancer("pause", Route.mettreEnPauseMission(mission.id)) }
                    .buttonStyle(.allurePuce)
            }
            // `☠` `requires_action` compte comme un tour EN VOL : un lead figé
            // sur une permission qu'on ne veut pas donner est le cas où couper
            // presse le plus.
            if etat.tourEnVol {
                Button("Interrompre") { lancer("interruption", Route.interrompreMission(mission.id)) }
                    .buttonStyle(.allurePuce(.vigilance))
            }
            Button("Inspecter") { lancer("inspection", Route.inspecterMission(mission.id)) }
                .buttonStyle(.allurePuce)
        }
        .disabled(enCours != nil)
        .opacity(enCours == nil ? 1 : 0.5)
    }

    private var libelleFin: String {
        ConstatDepot.lire(mission.git).travailEnJeu
            ? "Terminer — du travail non commité sera perdu"
            : "Terminer l'équipe"
    }

    // MARK: - Ordres

    private func lancer(_ nom: String, _ chemin: String) {
        Task { await ecrire(nom, chemin) }
    }

    private func ecrire(_ nom: String, _ chemin: String) async {
        guard enCours == nil else { return }
        enCours = nom
        defer { enCours = nil }
        switch await client.ecrire(chemin) {
        case .success(let accuse):
            retour = accuse.effet.isEmpty ? "\(nom) prise en compte." : accuse.effet
            await apres()
        case .failure(let erreur):
            retour = erreur.message
        }
    }

    /// `☠` Le seul geste destructeur du domaine : la garde biométrique
    /// s'ajoute au maintien du doigt, et le motif rappelle ce qui sera perdu.
    private func terminer() async {
        let enJeu = ConstatDepot.lire(mission.git).travailEnJeu
        let motif = enJeu
            ? "Terminer \(mission.title) — du travail non commité sera perdu"
            : "Terminer \(mission.title)"
        if case .refusee(let raison) = await GardeFaceID.exiger(motif) {
            retour = "Rien n'a été transmis : \(raison)"
            return
        }
        await ecrire("fin", Route.terminerMission(mission.id))
    }
}
#endif
