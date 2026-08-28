// Édition d'une note existante. On rouvre le texte et les tags, on corrige, ça
// repart vers le serveur sous le MÊME id — l'upsert idempotent met à jour au
// lieu de créer. Présenté en feuille depuis la besace.
//
// `☠` Priorité de Chris : l'intuitivité. Un tap sur une note l'ouvre ici,
// pré-remplie ; « Enregistrer » suffit. Aucune espèce à choisir, aucun id à voir.
#if canImport(SwiftUI)
import SwiftUI
import SailyNoyau

struct EditionNoteEcran: View {
    @Environment(Boite.self) private var boite
    @Environment(\.dismiss) private var fermer
    let item: Item

    @State private var texte: String
    @State private var tagsBruts: String
    @State private var enCours = false

    init(item: Item) {
        self.item = item
        _texte = State(initialValue: item.text)
        _tagsBruts = State(initialValue: item.tags.joined(separator: ", "))
    }

    var body: some View {
        ZStack {
            Teinte.fond.ignoresSafeArea()
            ScrollView { contenu }
        }
        // L'action primaire EN BAS, dans la zone du pouce, toujours visible — pas
        // noyée dans le défilement.
        .safeAreaInset(edge: .bottom) { barreAction }
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: Trame.section) {
            enTete
            champTexte
            champTags
        }
        .padding(.vertical, Trame.groupe)
    }

    private var enTete: some View {
        HStack(alignment: .firstTextBaseline) {
            Fronton("Modifier").padding(.top, Trame.serre)
            Spacer(minLength: 0)
            BoutonIcone("xmark.circle.fill") { fermer() }
                .padding(.trailing, Trame.serre)
        }
    }

    private var champTexte: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.serre) {
                Text("La note").rubrique()
                TextEditor(text: $texte)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140, maxHeight: 320)
                    .corps()
                    .foregroundStyle(Teinte.encre)
                    .tint(Teinte.accent)
            }
        }
        .padding(.horizontal, Trame.ecran)
    }

    private var champTags: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.serre) {
                Text("Tags").rubrique()
                TextField("séparés par des virgules", text: $tagsBruts)
                    .textFieldStyle(.plain)
                    .corps()
                    .foregroundStyle(Teinte.encre)
                    .tint(Teinte.accent)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.horizontal, Trame.ecran)
    }

    /// La barre d'action posée en bas de la feuille. Un fond de surface + un
    /// filet de lumière en tête la détachent du contenu qui défile dessous.
    private var barreAction: some View {
        Button { Task { await enregistrer() } } label: {
            if enCours {
                ProgressView().tint(Teinte.fond)
            } else {
                Text("Enregistrer")
            }
        }
        .buttonStyle(.engage)
        .disabled(texteCoupe.isEmpty || enCours)
        .padding(.horizontal, Trame.ecran)
        .padding(.top, Trame.element)
        .padding(.bottom, Trame.serre)
        .background(alignment: .top) {
            Rectangle().fill(Teinte.trait).frame(height: Trame.trait)
        }
        .background(Teinte.fond)
        .sensoryFeedback(Retour.engage, trigger: enCours) { avant, apres in avant && !apres }
    }

    // MARK: - Actions

    private func enregistrer() async {
        guard !texteCoupe.isEmpty else { return }
        enCours = true
        await boite.modifier(item, texte: texteCoupe, tags: tags)
        enCours = false
        fermer()
    }

    // MARK: - Dérivé

    private var texteCoupe: String {
        texte.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var tags: [String] {
        tagsBruts.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
#endif
