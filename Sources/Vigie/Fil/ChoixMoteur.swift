// Le moteur du prochain message : modèle, effort, mode rapide, ultracode.
//
// `☠` Portée SESSION, comme côté harness : la route `…/message` accepte ces
// quatre champs et le fil garde son réglage quand ils sont ABSENTS. Un champ
// n'est donc envoyé que si Chris l'a explicitement touché — `fastMode` forcé à
// `false` couperait le mode rapide à chaque message qui n'en parle pas.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Ce que le composeur enverra avec le prochain message. Tout à `nil` = le fil
/// garde son réglage, rien ne part sur le réseau.
struct ChoixMoteur: Equatable {
    var modele: String?
    var effort: String?
    var fastMode: Bool?
    var ultracode: Bool?

    var estNeutre: Bool {
        modele == nil && effort == nil && fastMode == nil && ultracode == nil
    }

    /// L'étiquette du composeur : le choix en cours, ou rien.
    var etiquette: String? {
        var morceaux: [String] = []
        if let modele { morceaux.append(modele) }
        if let effort { morceaux.append(effort) }
        if fastMode == true { morceaux.append("rapide") }
        if ultracode == true { morceaux.append("ultracode") }
        return morceaux.isEmpty ? nil : morceaux.joined(separator: " · ")
    }

    /// Verse les champs touchés dans le corps du message.
    func verser(dans champs: inout [String: ValeurJSON]) {
        if let modele { champs["model"] = .texte(modele) }
        if let effort { champs["effort"] = .texte(effort) }
        if let fastMode { champs["fastMode"] = .booleen(fastMode) }
        if let ultracode { champs["ultracode"] = .booleen(ultracode) }
    }
}

/// La feuille de choix : le catalogue réel du Pi, les efforts du modèle
/// choisi, et les deux bascules — grisées quand le modèle les refuse.
struct ChoixMoteurFeuille: View {
    let catalogue: [ModeleApi]
    /// Le modèle actuellement actif sur le fil (`DetailFilApi.model`).
    let modeleDuFil: String?
    @Binding var choix: ChoixMoteur

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Trame.bloc) {
                Text("Moteur du prochain message")
                    .titreFeuille()
                    .foregroundStyle(Teinte.encre)
                if catalogue.isEmpty {
                    BandeauNote("Catalogue indisponible — le Pi n'a pas encore rendu la liste.", ton: .vigilance)
                } else {
                    blocModeles
                    blocEffort
                    blocBascules
                    pied
                }
            }
            .padding(Trame.ecran)
        }
        .scrollIndicators(.hidden)
    }

    /// Le modèle EFFECTIF : le choix, sinon celui du fil.
    private var effectif: ModeleApi? {
        if let id = choix.modele { return catalogue.first { $0.id == id } }
        return catalogue.first { $0.id == modeleDuFil }
    }

    private var blocModeles: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Text("Modèle").insigne().foregroundStyle(Teinte.encreDouce)
            FluxPuces(elements: catalogue.map(\.id)) { id in
                let modele = catalogue.first { $0.id == id }
                let actif = effectif?.id == id
                Button {
                    choisir(modele)
                } label: {
                    Text(modele?.label ?? id)
                }
                .buttonStyle(.allurePuce(actif ? .attention : .neutre))
                .opacity(modele?.enabled == false ? 0.45 : 1)
            }
            if let note = effectif?.note, !note.isEmpty {
                Text(note).mention().foregroundStyle(Teinte.encreTernie)
            }
        }
        .sensoryFeedback(Haptique.selection, trigger: choix.modele)
    }

    /// `☠` Un modèle sans effort (Haiku) IGNORE le paramètre en silence : le
    /// sélecteur se grise, sinon Chris croit régler quelque chose.
    @ViewBuilder private var blocEffort: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Text("Effort").insigne().foregroundStyle(Teinte.encreDouce)
            if let modele = effectif, !modele.effort.isEmpty {
                FluxPuces(elements: modele.effort) { niveau in
                    Button(niveau) { choix.effort = niveau }
                        .buttonStyle(.allurePuce(choix.effort == niveau ? .attention : .neutre))
                }
            } else {
                Text("Ce modèle refuse le paramètre d'effort.")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            }
        }
        .sensoryFeedback(Haptique.selection, trigger: choix.effort)
    }

    private var blocBascules: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            bascule(
                "Mode rapide",
                aide: effectif?.fastMode == true ? nil : "réservé à la famille Opus récente",
                valeur: Binding(
                    get: { choix.fastMode ?? false },
                    set: { choix.fastMode = $0 }
                )
            )
            .disabled(effectif?.fastMode != true)
            bascule(
                "Ultracode",
                aide: effectif?.ultracode == true
                    ? "réappliqué à chaque message — portée session"
                    : "exige un modèle qui accepte xhigh",
                valeur: Binding(
                    get: { choix.ultracode ?? false },
                    set: { choix.ultracode = $0 }
                )
            )
            .disabled(effectif?.ultracode != true)
        }
    }

    private func bascule(_ titre: String, aide: String?, valeur: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(titre, isOn: valeur)
                .phrase()
                .foregroundStyle(Teinte.encre)
                .tint(Teinte.accent)
            if let aide {
                Text(aide).mention().foregroundStyle(Teinte.encreTernie)
            }
        }
        .sensoryFeedback(Haptique.selection, trigger: valeur.wrappedValue)
    }

    private var pied: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            FiletFin()
            Button("Laisser le fil sur son réglage") {
                choix = ChoixMoteur()
            }
            .buttonStyle(.allurePuce)
            .disabled(choix.estNeutre)
            Text("Le choix part avec le prochain message, puis reste acquis au fil.")
                .mention()
                .foregroundStyle(Teinte.encreTernie)
        }
    }

    private func choisir(_ modele: ModeleApi?) {
        guard let modele else { return }
        choix.modele = modele.id
        // Reprojection de l'effort sur ce que le modèle accepte réellement.
        if modele.effort.isEmpty {
            choix.effort = nil
        } else if let effort = choix.effort, !modele.effort.contains(effort) {
            choix.effort = modele.effortDefaut ?? modele.effort.first
        }
        if modele.fastMode != true { choix.fastMode = nil }
        if modele.ultracode != true { choix.ultracode = nil }
    }
}

/// Rangée de puces qui replie à la largeur : un simple défilement horizontal —
/// sept modèles ne tiennent pas sur 375 pt.
struct FluxPuces<Contenu: View>: View {
    let elements: [String]
    @ViewBuilder let contenu: (String) -> Contenu

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Trame.serre) {
                ForEach(elements, id: \.self, content: contenu)
            }
        }
        .scrollIndicators(.hidden)
    }
}
#endif
