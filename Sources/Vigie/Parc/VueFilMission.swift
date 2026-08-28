// Le fil d'une équipe, rendu par segments : les valises d'outils repliées, les
// transitions en français, les paroles du lead en markdown — la seule chose
// qu'on vient lire.
//
// `☠` Les identités viennent du noyau (`SegmentMission.id`, stable d'un relevé
// à l'autre) : sans elles, chaque battement refermerait les blocs dépliés et
// rejetterait le défilement.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct VueFilMission: View {
    let segments: [SegmentMission]
    /// Pour rapprocher une délégation de son sous-agent — la description est
    /// la SEULE clé de rapprochement, et elle peut manquer.
    let sousAgents: [SubagentApi]
    let missionId: String
    let partiel: PartielApi?

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            ForEach(segments) { segment in
                VueSegmentMission(segment: segment, sousAgents: sousAgents, missionId: missionId)
            }
            if let partiel { partielEnCours(partiel) }
        }
    }

    /// Le bloc en cours de frappe du lead — relevé seulement pour la mission
    /// réellement regardée.
    private func partielEnCours(_ partiel: PartielApi) -> some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            if partiel.type == .reflexion {
                Text(partiel.contenu)
                    .note()
                    .italic()
                    .foregroundStyle(Teinte.encreDouce)
            } else {
                RenduMarkdown(partiel.contenu)
            }
            SouffleActivite(teinte: Teinte.accent)
        }
    }
}

private struct VueSegmentMission: View {
    let segment: SegmentMission
    let sousAgents: [SubagentApi]
    let missionId: String

    var body: some View {
        switch segment.genre {
        case .parole:
            parole
        case .operateur:
            instruction
        case .permission:
            permission
        case .systeme:
            transition
        case .pensees:
            ValiseRepliee(
                symbole: "brain",
                resume: "\(segment.elements.count) moment\(segment.elements.count > 1 ? "s" : "") de réflexion",
                duree: segment.duree,
                heure: segment.derniere.ts
            ) {
                Text(segment.lignes.map(\.text).joined(separator: "\n\n"))
                    .note()
                    .italic()
                    .foregroundStyle(Teinte.encreDouce)
            }
        case .outils(let delegation):
            if delegation {
                delegations
            } else {
                valiseOutils
            }
        }
    }

    // MARK: - Genres

    private var parole: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            RenduMarkdown(segment.premiere.text)
            Text(segment.derniere.ts)
                .donneeMinuscule()
                .foregroundStyle(Teinte.encreTernie)
        }
    }

    /// La voix de Chris dans le fil du lead : même bulle qu'au Fil.
    private var instruction: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(segment.premiere.text)
                .phrase()
                .foregroundStyle(Teinte.encre)
                .padding(.horizontal, Trame.element)
                .padding(.vertical, Trame.serre + 2)
                .background(
                    Teinte.accent.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            Text(segment.premiere.ts)
                .donneeMinuscule()
                .foregroundStyle(Teinte.encreTernie)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 44)
    }

    /// `☠` Une autorisation RÉSOLUE SEULE et une autorisation qui ATTEND ne se
    /// peignent pas pareil : la seconde bloque le travail.
    private var permission: some View {
        let attente = segment.premiere.pending == true
        return HStack(alignment: .firstTextBaseline, spacing: Trame.serre) {
            Image(systemName: attente ? "hand.raised.fill" : "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(attente ? Teinte.accent : Teinte.encreTernie)
            Text(segment.premiere.text)
                .note()
                .foregroundStyle(attente ? Teinte.encre : Teinte.encreDouce)
            Spacer(minLength: 0)
            Text(segment.premiere.ts)
                .donneeMinuscule()
                .foregroundStyle(Teinte.encreTernie)
        }
        .padding(Trame.serre + 2)
        .background(
            attente ? Ton.attention.voile : Teinte.fondCreux,
            in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
        )
    }

    /// Une rafale de transitions : la phrase du Pi, centrée — un fait
    /// d'administration, pas une parole.
    private var transition: some View {
        HStack(spacing: Trame.serre) {
            FiletFin()
            Text("\(TransitionEquipe.lisible(segment.lignes)) · \(segment.derniere.ts)")
                .mention()
                .foregroundStyle(Teinte.encreTernie)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            FiletFin()
        }
    }

    private var valiseOutils: some View {
        ValiseRepliee(
            symbole: "wrench.and.screwdriver.fill",
            resume: LibelleValise.pour(segment.lignes),
            duree: segment.duree,
            heure: segment.derniere.ts
        ) {
            VStack(alignment: .leading, spacing: Trame.serre) {
                ForEach(segment.elements) { element in
                    LigneOutilMission(ligne: element.evenement)
                }
            }
        }
    }

    /// `☠` Une délégation ne se fond jamais dans la valise voisine : c'est le
    /// seul endroit du fil où l'équipe grandit. Quand la description rapproche
    /// un sous-agent du registre, la ligne ouvre son fil.
    private var delegations: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            ForEach(segment.elements) { element in
                delegation(element.evenement)
            }
        }
    }

    @ViewBuilder private func delegation(_ ligne: FeedEventApi) -> some View {
        let nom = LibelleOutil.nomDelegation(ligne)
        let agent = sousAgents.first { $0.name == nom }
        if let agent {
            NavigationLink(value: RouteParc.sousAgent(missionId, agent.id)) {
                etiquetteDelegation(nom: agent.name, navigable: true)
            }
            .buttonStyle(.allureCarte)
        } else {
            etiquetteDelegation(nom: nom ?? "un sous-agent", navigable: false)
        }
    }

    private func etiquetteDelegation(nom: String, navigable: Bool) -> some View {
        HStack(spacing: Trame.serre) {
            Image(systemName: "person.fill.badge.plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Teinte.veille)
            Text("Délégué à \(nom)")
                .note()
                .foregroundStyle(Teinte.encre)
            Spacer(minLength: 0)
            if navigable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Teinte.encreTernie)
            }
        }
        .padding(Trame.serre + 2)
        .background(Ton.veille.voile, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
    }
}

/// Une rafale repliée sous son résumé : la ligne se lit, le détail se creuse.
private struct ValiseRepliee<Contenu: View>: View {
    let symbole: String
    let resume: String
    let duree: Int?
    let heure: String
    @ViewBuilder let contenu: () -> Contenu

    @State private var depliee = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Elan.pose) { depliee.toggle() }
            } label: {
                ligne.contentShape(.rect)
            }
            .buttonStyle(.plain)
            if depliee {
                contenu()
                    .padding(.top, Trame.serre)
                    .transition(.opacity)
            }
        }
    }

    private var ligne: some View {
        HStack(alignment: .firstTextBaseline, spacing: Trame.serre) {
            Image(systemName: symbole)
                .font(.system(size: 10))
            Text(resume)
                .note()
            Spacer(minLength: 0)
            if let duree {
                Text(DureeLisible.texte(millisecondes: duree))
                    .donneeMinuscule()
            }
            Text(heure)
                .donneeMinuscule()
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .rotationEffect(.degrees(depliee ? 90 : 0))
        }
        .foregroundStyle(Teinte.encreDouce)
    }
}

/// Une ligne d'outil dépliée : l'heure, le résumé, la sortie si elle est là.
private struct LigneOutilMission: View {
    let ligne: FeedEventApi

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: Trame.serre) {
                Text(ligne.ts)
                    .donneeMinuscule()
                    .foregroundStyle(Teinte.encreTernie)
                Text(LibelleOutil.resume(ligne))
                    .donneePetite()
                    .foregroundStyle(ligne.resultError == true ? Teinte.danger : Teinte.encre)
            }
            // Absente tant que le résultat n'est pas revenu : un appel sans
            // sortie est un appel en vol, pas un appel qui a répondu du vide.
            if let sortie = ligne.result, !sortie.isEmpty {
                Text(sortie)
                    .donneeMinuscule()
                    .foregroundStyle(ligne.resultError == true ? Teinte.danger : Teinte.encreDouce)
                    .lineLimit(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Trame.serre)
        .background(Teinte.fondCreux, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
    }
}
#endif
