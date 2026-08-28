// Rendu d'un `BlocAgent` : ce que l'orchestrateur dit (markdown, à nu), ce
// qu'il pense (replié), ses outils (rafale repliée), ses échecs et les faits
// du harness (toujours visibles).
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct VueBlocAgent: View {
    let bloc: BlocAgent

    var body: some View {
        switch bloc {
        case .parole(_, let texte, _):
            RenduMarkdown(texte)
        case .reflexion(_, let texte, _):
            VueReflexion(texte: texte)
        case .outils(let groupe):
            VueGroupeOutils(groupe: groupe)
        case .echec(_, let texte, _):
            BandeauNote(texte, ton: .danger)
        case .fait(_, let texte, let at):
            VueFaitHarness(texte: texte, at: at)
        case .artefact(_, let piece, _):
            CarteArtefact(piece: piece)
        }
    }
}

/// Un fait du harness remis dans le fil (H-66) : sa propre voix — ni une
/// parole du lead, ni une instruction de Chris.
private struct VueFaitHarness: View {
    let texte: String
    let at: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Trame.serre) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Teinte.veille)
            Text(texte)
                .note()
                .foregroundStyle(Teinte.encreDouce)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(heureFil(at))
                .donneeMinuscule()
                .foregroundStyle(Teinte.encreTernie)
        }
        .padding(Trame.serre + 2)
        .background(Ton.veille.voile, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
    }
}

/// Le raisonnement : replié par défaut — c'est ce qu'on lit en creusant, pas
/// ce qu'on vient chercher.
private struct VueReflexion: View {
    let texte: String
    @State private var deplie = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Elan.pose) { deplie.toggle() }
            } label: {
                HStack(spacing: Trame.fin + 1) {
                    Image(systemName: "brain")
                        .font(.system(size: 10))
                    Text("Raisonnement")
                        .mention()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .rotationEffect(.degrees(deplie ? 90 : 0))
                }
                .foregroundStyle(Teinte.encreTernie)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if deplie {
                Text(texte)
                    .note()
                    .italic()
                    .foregroundStyle(Teinte.encreDouce)
                    .padding(.top, Trame.serre)
                    .padding(.leading, Trame.element)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Teinte.filetAppuye).frame(width: 2)
                    }
                    .transition(.opacity)
            }
        }
    }
}

/// Une rafale d'appels d'outils, résumée en une ligne. `☠` Elle se referme dès
/// que l'agent reprend la parole (`SegmentationFil`) : huit cartes pour un
/// tour rendraient le fil illisible.
private struct VueGroupeOutils: View {
    let groupe: GroupeOutils
    @State private var deplie = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Elan.pose) { deplie.toggle() }
            } label: {
                resume.contentShape(.rect)
            }
            .buttonStyle(.plain)
            if deplie {
                VStack(alignment: .leading, spacing: Trame.serre) {
                    ForEach(groupe.appels) { appel in
                        VueAppelOutil(appel: appel)
                    }
                }
                .padding(.top, Trame.serre)
                .transition(.opacity)
            }
        }
    }

    private var resume: some View {
        HStack(spacing: Trame.serre) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 10))
            Text(libelleResume)
                .note()
            if groupe.enAttente > 0 { SouffleActivite() }
            if groupe.echecs > 0 {
                Sceau("\(groupe.echecs) échec\(groupe.echecs > 1 ? "s" : "")", ton: .danger)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .rotationEffect(.degrees(deplie ? 90 : 0))
        }
        .foregroundStyle(Teinte.encreDouce)
    }

    private var libelleResume: String {
        let n = groupe.appels.count
        return n == 1 ? (groupe.appels.first?.nom ?? "outil") : "\(n) appels d'outils"
    }
}

/// Un appel déplié : nom, paramètres, résultat — ou l'attente. `resultat` à
/// `nil` veut dire « pas encore revenu », jamais « vide ».
private struct VueAppelOutil: View {
    let appel: AppelOutil

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            Text(appel.nom)
                .donneePetite()
                .foregroundStyle(Teinte.encre)
            if let detail = appel.detail, !detail.isEmpty {
                Text(detail)
                    .donneeMinuscule()
                    .foregroundStyle(Teinte.encreTernie)
                    .lineLimit(3)
            }
            resultat
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Trame.serre)
        .background(
            appel.enEchec ? Ton.danger.voile : Teinte.fondCreux,
            in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
        )
    }

    @ViewBuilder private var resultat: some View {
        if let resultat = appel.resultat {
            Text(resultat)
                .donneeMinuscule()
                .foregroundStyle(appel.enEchec ? Teinte.danger : Teinte.encreDouce)
                .lineLimit(6)
        } else {
            HStack(spacing: Trame.fin) {
                SouffleActivite()
                Text("en attente de résultat")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            }
        }
    }
}
#endif
