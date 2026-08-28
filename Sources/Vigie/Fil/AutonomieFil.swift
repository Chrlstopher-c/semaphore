// L'autonomie d'un fil : la fenêtre pendant laquelle on lui lâche la main, et
// le plafond d'équipes qu'il peut lancer sans clic.
//
// `☠` Le plafond ne s'écrit pas ici : il ne change que par une RALLONGE que le
// fil demande lui-même et que Chris tranche au Quart. Cette section le montre,
// elle ne le négocie pas. La fenêtre, elle, a sa route (`…/autonomie`) :
// `{start, end, goal}` en ms — corps vide pour la retirer.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct AutonomieFil: View {
    @Environment(\.clientPi) private var client

    let identifiant: String
    let detail: DetailFilApi?
    @Binding var avis: String?
    let apres: () async -> Void

    @State private var fin = Date().addingTimeInterval(4 * 3600)
    @State private var objectif = ""
    @State private var enCours = false

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            TeteDeSection("Autonomie")
            etatCourant
            reglage
        }
    }

    // MARK: - État

    private var fenetreActive: Bool {
        guard let fin = detail?.autonomieFin else { return false }
        return Lisible.instant(fin) > Date()
    }

    @ViewBuilder private var etatCourant: some View {
        VStack(spacing: 0) {
            if fenetreActive, let finMs = detail?.autonomieFin {
                LigneCle(
                    "Fenêtre",
                    valeur: Lisible.plage(debut: detail?.autonomieDebut, fin: finMs) ?? "—",
                    teinteValeur: Teinte.accent
                )
                if let objectif = detail?.autonomieObjectif {
                    LigneCleLongue("Objectif", valeur: objectif)
                }
            } else {
                LigneCle("Fenêtre", valeur: "aucune — chaque mandat attend ton clic")
            }
            LigneCle("Plafond", valeur: detail?.plafondAutonomie.libelle ?? "—", derniere: true)
        }
    }

    // MARK: - Réglage

    @ViewBuilder private var reglage: some View {
        if fenetreActive {
            Button("Retirer l'autonomie") { Task { await retirer() } }
                .buttonStyle(.allurePuce(.danger))
                .disabled(enCours)
        } else {
            VStack(alignment: .leading, spacing: Trame.serre) {
                DatePicker(
                    "Lâcher la main jusqu'à",
                    selection: $fin,
                    in: Date().addingTimeInterval(600)...Date().addingTimeInterval(48 * 3600)
                )
                .note()
                .foregroundStyle(Teinte.encre)
                .tint(Teinte.accent)
                ChampQuart(
                    texte: $objectif,
                    placebo: "Objectif de la fenêtre (facultatif)",
                    lignes: 1...3
                )
                Button("Déléguer jusqu'à \(heure(fin))") { Task { await poser() } }
                    .buttonStyle(.allureDouce)
                    .disabled(enCours)
                Text("Pendant la fenêtre, les mandats de ce fil partent sans ton clic, "
                    + "dans la limite du plafond. Le plafond ne change que par une "
                    + "rallonge, tranchée au Quart.")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            }
        }
    }

    private func heure(_ date: Date) -> String {
        Lisible.heure(Int(date.timeIntervalSince1970 * 1000))
    }

    // MARK: - Écritures

    private func poser() async {
        var champs: [String: ValeurJSON] = [
            "start": .entier(Int(Date().timeIntervalSince1970 * 1000)),
            "end": .entier(Int(fin.timeIntervalSince1970 * 1000)),
        ]
        let but = objectif.trimmingCharacters(in: .whitespacesAndNewlines)
        if !but.isEmpty { champs["goal"] = .texte(but) }
        await ecrire(CorpsJSON(champs))
    }

    /// `☠` Corps VIDE = retrait : le serveur lit `start`/`end` absents comme
    /// `null` et referme la fenêtre.
    private func retirer() async {
        await ecrire(CorpsJSON([:]))
    }

    private func ecrire(_ corps: CorpsJSON) async {
        guard !enCours else { return }
        enCours = true
        defer { enCours = false }
        switch await client.ecrire(Route.autonomieDuFil(identifiant), corps) {
        case .success(let accuse):
            avis = accuse.effet
            await apres()
        case .failure(let erreur):
            avis = erreur.message
        }
    }
}
#endif
