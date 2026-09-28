// Le fil d'une session : messages de Chris, texte de Claude, outils dépliables, sous-agents et leur travail, jalons.
// Collé en bas à l'arrivée d'un événement (défilement ancré), comme une conversation.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct FilVue: View {
    @Environment(\.palette) private var p
    let evenements: [EvenementDate]
    let dossier: String

    var body: some View {
        let elements = StructureFil.structurer(evenements)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Espace.s) {
                if elements.isEmpty {
                    EtatVide(symbole: "text.bubble", titre: "Rien pour l’instant", texte: "Le fil s’affiche dès que Claude travaille.")
                }
                ForEach(elements) { element in
                    switch element {
                    case .outil(let o): CarteOutilVue(appel: o, dossier: dossier)
                    case .sousAgent(let a): CarteSousAgentVue(agent: a, dossier: dossier)
                    case .simple(_, let ts, let evt): ElementSimpleVue(evt: evt, ts: ts)
                    }
                }
            }
            .padding(.horizontal, Espace.marge).padding(.vertical, Espace.l)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
    }
}

struct ElementSimpleVue: View {
    @Environment(\.palette) private var p
    let evt: Evenement
    let ts: String

    var body: some View {
        switch evt {
        case .message(let texte): bulle(texte)
        case .texte(let texte, _): Text(markdown(texte)).font(Voix.lecture).foregroundStyle(p.encre).textSelection(.enabled)
        case .reflexion(let texte, _): reflexion(texte)
        case .etape(let resume, let suite): Jalon(symbole: "flag.fill", titre: "Étape livrée", texte: "\(resume)\n→ \(suite)", ton: p.accentTexte)
        case .objectifAtteint(let bilan): Jalon(symbole: "checkmark.circle.fill", titre: "Objectif atteint", texte: bilan, ton: p.succes)
        case .question(let q): Jalon(symbole: "questionmark.circle.fill", titre: "Question pour toi", texte: q, ton: p.alerte)
        case .erreur(let m): Jalon(symbole: "exclamationmark.triangle.fill", titre: "Erreur", texte: m, ton: p.danger)
        case .compaction(let avant, let apres, _): filet("compactée · \(Format.tokens(avant)) → \(Format.tokens(apres))")
        case .relance(let raison): filet(raison)
        default: EmptyView()
        }
    }

    private func bulle(_ texte: String) -> some View {
        HStack {
            Spacer(minLength: 48)
            Text(texte).font(Voix.lecture).foregroundStyle(.white).padding(.horizontal, Espace.l).padding(.vertical, Espace.m)
                .background(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 6,
                                                   topTrailingRadius: 18, style: .continuous).fill(p.accent))
        }
        .padding(.vertical, Espace.xs)
    }

    private func reflexion(_ texte: String) -> some View {
        Text(String(texte.prefix(900))).font(Voix.petit).italic().foregroundStyle(p.discret)
            .padding(.leading, Espace.m).overlay(alignment: .leading) { Rectangle().fill(p.filet).frame(width: 2) }
    }

    private func filet(_ texte: String) -> some View {
        HStack(spacing: Espace.s) {
            Rectangle().fill(p.filet).frame(height: 1)
            Text(texte).font(Voix.etiquette).foregroundStyle(p.discret).lineLimit(1).fixedSize()
            Rectangle().fill(p.filet).frame(height: 1)
        }
        .padding(.vertical, Espace.xs)
    }
}

struct Jalon: View {
    @Environment(\.palette) private var p
    let symbole: String
    let titre: String
    let texte: String
    let ton: Color

    var body: some View {
        HStack(alignment: .top, spacing: Espace.m) {
            Image(systemName: symbole).foregroundStyle(ton)
            VStack(alignment: .leading, spacing: Espace.xs) {
                Text(titre).font(Voix.petit.weight(.heavy)).foregroundStyle(ton)
                Text(texte).font(Voix.lecture).foregroundStyle(p.encre)
            }
            Spacer(minLength: 0)
        }
        .padding(Espace.m)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ton.opacity(0.12)))
    }
}

/// Markdown en ligne natif (gras, code, liens) ; un texte mal formé reste lisible tel quel.
func markdown(_ texte: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: texte, options: options)) ?? AttributedString(texte)
}
#endif
