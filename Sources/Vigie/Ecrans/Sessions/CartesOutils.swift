// Un appel d'outil et un sous-agent dans le fil : une ligne compacte, qui se déplie pour tout voir (entrée, résultat,
// et pour un sous-agent, chacun de ses outils et son rapport).
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct CarteOutilVue: View {
    @Environment(\.palette) private var p
    let appel: AppelOutil
    let dossier: String
    @State private var ouvert = false

    var body: some View {
        VStack(alignment: .leading, spacing: Espace.s) {
            Button { withAnimation(Mouvement.standard) { ouvert.toggle() } } label: { entete }.buttonStyle(.plain)
            if ouvert {
                BlocMono(titre: "Entrée", texte: appel.detail, erreur: false)
                if let r = appel.resultat { BlocMono(titre: r.erreur ? "Erreur" : "Résultat", texte: r.extrait, erreur: r.erreur) }
            }
        }
        .sensoryFeedback(.selection, trigger: ouvert)
    }

    private var entete: some View {
        HStack(spacing: Espace.s) {
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(p.discret)
                .rotationEffect(.degrees(ouvert ? 90 : 0))
            Image(systemName: symbole(appel.nom)).font(.system(size: 12)).foregroundStyle(appel.resultat?.erreur == true ? p.danger : p.accentTexte)
            Text(appel.nom).font(Voix.petit.weight(.bold)).foregroundStyle(p.encre)
            Text(appel.resume.replacingOccurrences(of: dossier + "/", with: "")).font(Voix.etiquette).foregroundStyle(p.discret).lineLimit(1)
            Spacer(minLength: 0)
            if appel.resultat == nil { PointEtat(ton: .actif) }
        }
        .frame(minHeight: 32).contentShape(Rectangle())
    }
}

struct CarteSousAgentVue: View {
    @Environment(\.palette) private var p
    let agent: SousAgent
    let dossier: String
    @State private var ouvert = false

    var body: some View {
        VStack(alignment: .leading, spacing: Espace.s) {
            Button { withAnimation(Mouvement.standard) { ouvert.toggle() } } label: { entete }.buttonStyle(.plain)
            if ouvert { interieur }
        }
        .carte()
        .sensoryFeedback(.selection, trigger: ouvert)
    }

    private var entete: some View {
        HStack(spacing: Espace.m) {
            Image(systemName: "sparkles").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.accentTexte)
                .frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(p.accentFond))
            VStack(alignment: .leading, spacing: Espace.xs) {
                Text(agent.description.isEmpty ? "Sous-agent" : agent.description).font(Voix.courant.weight(.bold))
                    .foregroundStyle(p.encre).lineLimit(1)
                Text("\(agent.genre) · \(agent.nombreOutils) outil\(agent.nombreOutils > 1 ? "s" : "")\(agent.modele.isEmpty ? "" : " · \(agent.modele)")")
                    .font(Voix.etiquette).foregroundStyle(p.discret)
            }
            Spacer(minLength: 0)
            Pastille(texte: agent.fin == nil ? "en cours" : "terminé", ton: agent.fin == nil ? .accent : .succes)
        }
        .contentShape(Rectangle())
    }

    private var interieur: some View {
        VStack(alignment: .leading, spacing: Espace.xs) {
            ForEach(agent.interieur) { element in
                if case .outil(let o) = element { CarteOutilVue(appel: o, dossier: dossier) }
            }
            if let rapport = agent.rapport { BlocMono(titre: agent.fin == nil ? "Dernier message" : "Rapport", texte: rapport, erreur: false) }
        }
        .padding(.leading, Espace.m)
        .overlay(alignment: .leading) { Rectangle().fill(p.accentFond).frame(width: 2) }
    }
}

struct BlocMono: View {
    @Environment(\.palette) private var p
    let titre: String
    let texte: String
    let erreur: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Espace.xs) {
            Text(titre.uppercased()).font(Voix.etiquette).tracking(1.2).foregroundStyle(p.discret)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(texte.isEmpty ? "—" : String(texte.prefix(3_000))).font(.custom("JetBrains Mono", size: 11))
                    .foregroundStyle(erreur ? p.danger : p.encreDouce).textSelection(.enabled)
            }
            .padding(Espace.s)
            .frame(maxWidth: .infinity, maxHeight: 220, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(erreur ? p.danger.opacity(0.1) : p.surface2))
        }
    }
}

private func symbole(_ outil: String) -> String {
    switch outil {
    case "Bash": return "terminal"
    case "Read": return "doc.text"
    case "Edit", "Write": return "pencil"
    case "Grep", "Glob": return "magnifyingglass"
    case "WebFetch", "WebSearch": return "globe"
    default: return "wrench.and.screwdriver"
    }
}
#endif
