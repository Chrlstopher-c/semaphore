// Les rappels programmés d'un fil : visibilité et contrôle, jamais la plume —
// la consigne est rédigée par l'orchestrateur, la création n'a pas de route.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct RappelsFil: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir

    let identifiant: String

    @State private var rappels: [RappelApi] = []
    @State private var releve = false
    @State private var enCours: String?
    @State private var aSupprimer: RappelApi?
    @State private var avis: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            TeteDeSection("Rappels") {
                if !rappels.isEmpty { Sceau("\(rappels.count)", ton: .neutre) }
            }
            contenu
        }
        .task { await relever() }
        .avisFugace($avis)
        .confirmationDialog(
            "Supprimer « \(aSupprimer?.label ?? "") » ?",
            isPresented: suppressionPresentee,
            titleVisibility: .visible
        ) {
            Button("Supprimer définitivement", role: .destructive) {
                if let rappel = aSupprimer { Task { await agir(rappel, action: "delete") } }
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    @ViewBuilder private var contenu: some View {
        if rappels.isEmpty {
            Text(releve ? "Aucun rappel sur ce fil." : "Relevé des rappels…")
                .mention()
                .foregroundStyle(Teinte.encreTernie)
        } else {
            VStack(spacing: Trame.serre) {
                ForEach(rappels) { rappel in
                    LigneRappel(
                        rappel: rappel,
                        occupee: enCours != nil,
                        basculer: { Task { await basculer(rappel) } },
                        supprimer: { aSupprimer = rappel }
                    )
                }
            }
        }
    }

    private var suppressionPresentee: Binding<Bool> {
        Binding(get: { aSupprimer != nil }, set: { present in if !present { aSupprimer = nil } })
    }

    // MARK: - Réseau

    private func relever() async {
        if let cache = await miroir.lire([RappelApi].self, .rappels(fil: identifiant)) {
            rappels = cache.valeur
        }
        let lecture = await client.lire(
            [RappelApi].self, Route.rappels(fil: identifiant), memoriser: .rappels(fil: identifiant)
        )
        if let charge = lecture.charge { rappels = charge }
        releve = true
    }

    /// `☠` ÉNUMÉRÉ, pas un booléen : « en pause » se reprend, « terminé »
    /// jamais — le bouton suit l'état, il ne le devine pas.
    private func basculer(_ rappel: RappelApi) async {
        let action = rappel.state == .enPause ? "resume" : "pause"
        await agir(rappel, action: action)
    }

    private func agir(_ rappel: RappelApi, action: String) async {
        guard enCours == nil else { return }
        enCours = rappel.id
        defer { enCours = nil }
        let chemin = Route.actionRappel(fil: identifiant, rappel: rappel.id, action: action)
        switch await client.ecrire(chemin) {
        case .success(let accuse):
            avis = accuse.effet
            await relever()
        case .failure(let erreur):
            // `☠` 409 = « rien n'a changé » : un rappel qu'on croit coupé et
            // qui continue de tirer. Le refus se lit tel quel.
            avis = erreur.message
        }
    }
}

/// Un rappel : le libellé, la consigne ENTIÈRE (c'est ce que l'orchestrateur
/// recevra mot pour mot), l'échéance absolue, et les deux gestes.
private struct LigneRappel: View {
    let rappel: RappelApi
    let occupee: Bool
    let basculer: () -> Void
    let supprimer: () -> Void

    @State private var depliee = false

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            entete
            consigne
            mesures
            if rappel.state != .termine { gestes }
            if let erreur = rappel.lastError {
                Text(erreur)
                    .mention()
                    .foregroundStyle(Teinte.vigilance)
            }
        }
        .padding(Trame.element)
        .background(Teinte.fondCreux, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
    }

    private var entete: some View {
        HStack(spacing: Trame.serre) {
            Text(rappel.label)
                .phraseForte()
                .foregroundStyle(Teinte.encre)
                .lineLimit(1)
            Spacer(minLength: 0)
            Sceau(libelleEtat, ton: tonEtat)
        }
    }

    private var consigne: some View {
        Text(rappel.instruction)
            .mention()
            .foregroundStyle(Teinte.encreDouce)
            .lineLimit(depliee ? nil : 2)
            .contentShape(.rect)
            .onTapGesture { withAnimation(Elan.pose) { depliee.toggle() } }
    }

    private var mesures: some View {
        HStack(spacing: Trame.serre) {
            if let prochain = rappel.nextAt {
                PuceDonnee("prochain \(Lisible.heure(prochain))")
            }
            if let cycle = rappel.everyMinutes {
                PuceDonnee("toutes les \(cycle) min")
            }
            PuceDonnee(tirs)
        }
    }

    private var tirs: String {
        guard let plafond = rappel.maxFires else { return "\(rappel.fired) tir\(rappel.fired > 1 ? "s" : "")" }
        return "\(rappel.fired)/\(plafond) tirs"
    }

    private var gestes: some View {
        HStack(spacing: Trame.serre) {
            Button(rappel.state == .enPause ? "Reprendre" : "Mettre en pause") { basculer() }
                .buttonStyle(.allurePuce)
                .disabled(occupee)
            Button("Supprimer") { supprimer() }
                .buttonStyle(.allurePuce(.danger))
                .disabled(occupee)
        }
    }

    private var libelleEtat: String {
        switch rappel.state {
        case .actif: return "actif"
        case .enPause: return "en pause"
        case .termine: return "terminé"
        default: return rappel.state.rawValue
        }
    }

    private var tonEtat: Ton {
        switch rappel.state {
        case .actif: return .sain
        case .enPause: return .veille
        default: return .neutre
        }
    }
}
#endif
