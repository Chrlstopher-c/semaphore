// Un dialogue du TUI en attente (question de Claude, permission, validation de plan), posé au-dessus du compositeur :
// on y répond comme au clavier, une question à la fois — la suivante arrive dès que le TUI l'affiche.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct DialogueVue: View {
    @Environment(ModeleRelais.self) private var modele
    let session: String
    let dialogue: Dialogue
    let repondable: Bool
    @Binding var erreur: String?
    @State private var cases: Set<Int> = []
    @State private var texte = ""
    @State private var envoi = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Claude attend ta réponse", systemImage: "questionmark.bubble.fill")
                .font(.footnote.weight(.semibold)).foregroundStyle(Charte.accent)
            if !dialogue.titre.isEmpty {
                Text(dialogue.titre).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(dialogue.options.enumerated()), id: \.offset) { i, o in
                        if i != dialogue.saisie { ligne(i, o) }
                    }
                }
            }
            .frame(maxHeight: 260)
            .scrollBounceBehavior(.basedOnSize)
            if repondable { pied }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.bar)
        .onAppear { cases = Set(dialogue.coches.filter { $0 != dialogue.saisie }) }
        .onChange(of: dialogue.id) {
            cases = Set(dialogue.coches.filter { $0 != dialogue.saisie })
            texte = ""
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: envoi)
    }

    private func ligne(_ i: Int, _ o: Dialogue.Option) -> some View {
        Button {
            if dialogue.multiple {
                if cases.contains(i) { cases.remove(i) } else { cases.insert(i) }
            } else {
                envoyer(ReponseDialogue(id: dialogue.id, index: i))
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if dialogue.multiple {
                    Image(systemName: cases.contains(i) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(cases.contains(i) ? Charte.accent : .secondary)
                } else {
                    Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 14)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(o.libelle).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    if !o.description.isEmpty { Text(o.description).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!repondable || envoi)
    }

    @ViewBuilder private var pied: some View {
        let libre = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        if dialogue.saisie != nil || dialogue.multiple {
            HStack(spacing: 8) {
                if dialogue.saisie != nil {
                    TextField("Autre réponse", text: $texte)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().strokeBorder(Color(.separator)))
                        .submitLabel(.send)
                        .onSubmit { if !dialogue.multiple && !libre.isEmpty { envoyerLibre(libre) } }
                }
                if dialogue.multiple {
                    Button("Valider") {
                        envoyer(ReponseDialogue(id: dialogue.id, cases: cases.sorted(), texte: libre.isEmpty ? nil : libre))
                    }
                    .buttonStyle(.borderedProminent).tint(Charte.accent)
                    .disabled(envoi || (cases.isEmpty && libre.isEmpty))
                } else {
                    Button("Envoyer") { envoyerLibre(libre) }
                        .buttonStyle(.bordered).disabled(envoi || libre.isEmpty)
                }
            }
        }
    }

    private func envoyerLibre(_ libre: String) {
        envoyer(ReponseDialogue(id: dialogue.id, texte: libre))
    }

    private func envoyer(_ r: ReponseDialogue) {
        envoi = true
        Task {
            erreur = await modele.repondre(r, a: session)
            envoi = false
        }
    }
}
#endif
