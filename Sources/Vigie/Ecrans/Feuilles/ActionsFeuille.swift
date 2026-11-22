// La feuille d'une suite d'actions (étalon 022/023) : titre = résumé, frise verticale d'appels reliés par un trait,
// chaque appel pousse son détail (commande et sortie, diff, sous-agent).
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ActionsFeuille: View {
    @Environment(\.dismiss) private var fermer
    let groupe: GroupeActions

    var body: some View {
        NavigationStack {
            ScrollView { Frise(elements: groupe.elements).padding(.top, 8) }
                .barreFeuille(groupe.resume)
                .toolbar { ToolbarItem(placement: .topBarLeading) { BoutonEntete(symbole: "xmark") { fermer() } } }
                .navigationDestination(for: AppelOutil.self) { DetailOutilVue(appel: $0) }
                .navigationDestination(for: SousAgent.self) { SousAgentVue(agent: $0) }
        }
        .feuilleQuart()
    }
}

extension AppelOutil: Hashable {
    public func hash(into h: inout Hasher) { h.combine(id); h.combine(outilId) }
}

extension SousAgent: Hashable {
    public func hash(into h: inout Hasher) { h.combine(id); h.combine(outilId) }
}

/// Les appels, reliés par un trait vertical gris entre leurs glyphes.
struct Frise: View {
    let elements: [ElementFil]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(elements.enumerated()), id: \.offset) { i, e in
                if i > 0 { Rectangle().fill(Q.rond).frame(width: 1.5, height: 18).padding(.leading, 35) }
                ligne(e)
            }
        }
    }

    @ViewBuilder private func ligne(_ e: ElementFil) -> some View {
        switch e {
        case .outil(let o): NavigationLink(value: o) { RangeeAppel(appel: o) }.buttonStyle(.plain)
        case .sousAgent(let a): NavigationLink(value: a) { RangeeAgent(agent: a) }.buttonStyle(.plain)
        case .simple: EmptyView()
        }
    }
}

private struct RangeeAppel: View {
    let appel: AppelOutil

    var body: some View {
        let d = DetailOutil.depuis(appel)
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: Charte.symbole(appel.nom)).font(.system(size: 17, weight: .light))
                .foregroundStyle(appel.resultat?.erreur == true ? Q.retraitTexte : Q.secondaire).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(titre(d)).font(Q.rangee).foregroundStyle(Q.texte).lineLimit(1)
                if let chemin = d.chemin { Text(nomFichier(chemin)).font(Q.detail).foregroundStyle(Q.tertiaire).lineLimit(1) }
            }
            Spacer(minLength: 8)
            if let plus = d.ajouts, plus > 0 { Text("+\(plus)").font(Q.detail).foregroundStyle(Q.ajout).monospacedDigit() }
            if let moins = d.suppressions, moins > 0 {
                Text("−\(moins)").font(Q.detail).foregroundStyle(Q.retrait).monospacedDigit()
            }
            if appel.resultat == nil { IndicateurTravail().frame(width: 14, height: 14) }
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium)).foregroundStyle(Q.meta)
        }
        .padding(.horizontal, 22).frame(minHeight: 48).contentShape(.rect)
    }

    private func titre(_ d: DetailOutil) -> String {
        switch appel.nom {
        case "Write": return "Créé"
        case "Edit", "MultiEdit": return "Modifié"
        case "Read": return "Lu"
        default: return d.titre.isEmpty ? appel.nom : d.titre
        }
    }

    private func nomFichier(_ chemin: String) -> String { (chemin as NSString).lastPathComponent }
}

private struct RangeeAgent: View {
    let agent: SousAgent

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "diamond").font(.system(size: 17, weight: .light)).foregroundStyle(Q.secondaire).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.description).font(Q.rangee).foregroundStyle(Q.texte).lineLimit(1)
                Text("Agent · \(agent.nombreOutils) outil\(agent.nombreOutils > 1 ? "s" : "")").font(Q.detail)
                    .foregroundStyle(Q.tertiaire)
            }
            Spacer(minLength: 8)
            if agent.fin == nil { IndicateurTravail().frame(width: 14, height: 14) }
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium)).foregroundStyle(Q.meta)
        }
        .padding(.horizontal, 22).frame(minHeight: 52).contentShape(.rect)
    }
}

/// Un sous-agent : sa mission, ses appels (même frise), son rapport.
private struct SousAgentVue: View {
    let agent: SousAgent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(agent.description).font(.system(size: 18)).foregroundStyle(Q.texte).padding(.horizontal, Q.margeTexte)
                Frise(elements: agent.interieur.compactMap(element))
                if let rapport = agent.rapport {
                    TitreSection(texte: "Rapport").padding(.horizontal, -8)
                    MarkdownVue(source: rapport).padding(.horizontal, Q.margeTexte)
                }
            }
            .padding(.vertical, 12)
        }
        .barreFeuille(agent.genre.isEmpty ? "Agent" : agent.genre)
    }

    private func element(_ i: ElementInterne) -> ElementFil? {
        if case .outil(let o) = i { return .outil(o) }
        return nil
    }
}
#endif
