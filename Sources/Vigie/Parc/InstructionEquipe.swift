// L'instruction glissée à une équipe en cours : la voix de Chris dans le fil
// du lead. Route `POST /missions/{id}/instruction`, corps `{ text }`.
//
// `☠` L'effet du serveur se lit EN PLACE, jamais en toast : « instruction
// retenue — la mission est en pause » change ce qu'on attend du geste.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct InstructionEquipe: View {
    @Environment(\.clientPi) private var client

    let mission: MissionApi
    let apres: () async -> Void

    @State private var texte = ""
    @State private var enCours = false
    @State private var effet: String?

    private var etat: EtatEquipe { EtatEquipe(mission.state) }

    var body: some View {
        if etat.pilotable {
            VStack(alignment: .leading, spacing: Trame.element) {
                TeteDeSection("Instruction au lead")
                HStack(alignment: .bottom, spacing: Trame.serre) {
                    ChampQuart(
                        texte: $texte,
                        placebo: "Consigne pour l'équipe…",
                        lignes: 1...4
                    )
                    bouton
                }
                if let effet {
                    Text(effet)
                        .note()
                        .foregroundStyle(Teinte.encreDouce)
                        .transition(.opacity)
                }
            }
            .animation(Elan.pose, value: effet)
        }
    }

    private var bouton: some View {
        Button {
            Task { await envoyer() }
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Teinte.encreSurAccent)
                .frame(width: 38, height: 38)
                .background(vide ? Teinte.surfaceHaute : Teinte.accent, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(vide || enCours)
        .accessibilityLabel("Envoyer l'instruction")
    }

    private var vide: Bool {
        texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func envoyer() async {
        let consigne = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !consigne.isEmpty, !enCours else { return }
        enCours = true
        defer { enCours = false }
        switch await client.ecrire(Route.instructionMission(mission.id), ["text": .texte(consigne)]) {
        case .success(let accuse):
            effet = accuse.effet
            texte = ""
            await apres()
        case .failure(let erreur):
            effet = erreur.message
        }
    }
}
#endif
