// Le fil d'une session, façon Messages : bulles pour Chris, texte pour Claude, outils et sous-agents repliés en
// `DisclosureGroup` natifs, jalons en libellés colorés. Ancré en bas, comme une conversation.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct FilVue<Entete: View>: View {
    let evenements: [EvenementDate]
    let dossier: String
    @ViewBuilder let entete: () -> Entete

    var body: some View {
        let elements = StructureFil.structurer(evenements)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                entete()
                if elements.isEmpty {
                    ContentUnavailableView("Rien pour l’instant", systemImage: "text.bubble",
                                           description: Text("Le fil s’affiche dès que Claude travaille."))
                }
                ForEach(elements) { element in
                    switch element {
                    case .outil(let o): LigneOutil(appel: o, dossier: dossier)
                    case .sousAgent(let a): LigneSousAgent(agent: a, dossier: dossier)
                    case .simple(_, let ts, let evt): ElementFil(evt: evt, ts: ts)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
    }
}

struct ElementFil: View {
    let evt: Evenement
    let ts: String

    var body: some View {
        switch evt {
        case .message(let texte): Bulle(texte: texte)
        case .texte(let texte, _): Text(markdown(texte)).font(.callout).textSelection(.enabled)
        case .reflexion(let texte, _): Text(String(texte.prefix(900))).font(.footnote).italic().foregroundStyle(.secondary)
        case .etape(let resume, let suite): Jalon(titre: "Étape livrée", texte: "\(resume)\n→ \(suite)", symbole: "flag.fill", couleur: Charte.accent)
        case .objectifAtteint(let bilan): Jalon(titre: "Objectif atteint", texte: bilan, symbole: "checkmark.circle.fill", couleur: .green)
        case .question(let q): Jalon(titre: "Question pour toi", texte: q, symbole: "questionmark.circle.fill", couleur: .orange)
        case .erreur(let m): Jalon(titre: "Erreur", texte: m, symbole: "exclamationmark.triangle.fill", couleur: .red)
        case .compaction(let avant, let apres, _): Signal(texte: "Compactée · \(Format.tokens(avant)) → \(Format.tokens(apres))")
        case .relance(let raison): Signal(texte: raison)
        default: EmptyView()
        }
    }
}

private struct Bulle: View {
    let texte: String

    var body: some View {
        HStack {
            Spacer(minLength: 48)
            Text(texte).font(.callout).foregroundStyle(.white).textSelection(.enabled)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Charte.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct Jalon: View {
    let titre: String
    let texte: String
    let symbole: String
    let couleur: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(titre, systemImage: symbole).font(.subheadline.weight(.semibold)).foregroundStyle(couleur)
            Text(texte).font(.callout).textSelection(.enabled)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(couleur.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct Signal: View {
    let texte: String

    var body: some View {
        Text(texte).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
    }
}

/// Markdown en ligne natif (gras, code, liens) ; un texte mal formé reste lisible tel quel.
func markdown(_ texte: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: texte, options: options)) ?? AttributedString(texte)
}
#endif
