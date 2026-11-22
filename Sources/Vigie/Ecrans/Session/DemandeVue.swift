// Une demande de Claude qui bloque la session : permission d'un outil (autoriser, toujours, refuser) ou question à
// choix. Carte posée au-dessus du composeur, dans la grammaire de l'étalon (carte #20201F, capsule blanche principale).
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct DemandeVue: View {
    @Environment(ModeleRelais.self) private var modele
    let session: Session
    let dialogue: Dialogue
    let erreur: (String) -> Void
    @State private var libre = ""
    @State private var cases: Set<Int> = []
    @State private var envoi = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titre).font(.system(size: 17, weight: .semibold)).foregroundStyle(Q.texte)
            if let p = dialogue.permission { permission(p) } else { question }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Q.carte, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Q.pilule))
        .padding(.horizontal, 16).padding(.top, 8)
        .background(Q.entete)
        .disabled(envoi)
        .onAppear { cases = Set(dialogue.coches) }
        .sensoryFeedback(.warning, trigger: dialogue.id)
    }

    private var titre: String {
        if let p = dialogue.permission { return "Autoriser \(p.outil) ?" }
        return dialogue.titre
    }

    @ViewBuilder private func permission(_ p: PermissionDialogue) -> some View {
        if !p.entree.isEmpty {
            ScrollView { Text(p.entree).font(Q.monoPetit).foregroundStyle(Q.codeTexte).frame(maxWidth: .infinity, alignment: .leading) }
                .frame(maxHeight: 120).padding(12)
                .background(Q.fondFil, in: .rect(cornerRadius: 12, style: .continuous))
        }
        VStack(spacing: 8) {
            boutonPlein("Autoriser") { repondreIndex(0) }
            if p.suggestion || dialogue.options.count > 2 { boutonSombre("Toujours autoriser") { repondreIndex(1) } }
            Button("Refuser") { repondreIndex(dialogue.options.count - 1) }
                .font(.system(size: 17)).foregroundStyle(Q.deconnexion).frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    @ViewBuilder private var question: some View {
        VStack(spacing: 0) {
            ForEach(Array(dialogue.options.enumerated()), id: \.offset) { i, o in
                if i > 0 { Filet(retrait: 0) }
                if i == dialogue.saisie { champLibre(o) } else { option(i, o) }
            }
        }
        if dialogue.multiple {
            boutonPlein("Valider") { envoyer(ReponseDialogue(id: dialogue.id, cases: cases.sorted())) }
        }
    }

    private func option(_ i: Int, _ o: Dialogue.Option) -> some View {
        Button { dialogue.multiple ? basculer(i) : repondreIndex(i) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if dialogue.multiple {
                    Image(systemName: cases.contains(i) ? "checkmark.square.fill" : "square").foregroundStyle(Q.coche)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(o.libelle).font(Q.rangee).foregroundStyle(Q.texte)
                    if !o.description.isEmpty { Text(o.description).font(Q.detail).foregroundStyle(Q.secondaire) }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10).contentShape(.rect)
        }
        .buttonStyle(StyleAppui())
    }

    private func champLibre(_ o: Dialogue.Option) -> some View {
        HStack {
            TextField(o.libelle, text: $libre).font(Q.rangee).foregroundStyle(Q.texte).submitLabel(.send)
                .onSubmit { envoyerLibre() }
            if !libre.isEmpty {
                BoutonRond(symbole: "arrow.up", diametre: 30, fond: Q.texte, encre: Q.carte, poids: .semibold) { envoyerLibre() }
            }
        }
        .padding(.vertical, 6)
    }

    private func boutonPlein(_ titre: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titre).font(.system(size: 17, weight: .medium)).foregroundStyle(Q.carte)
                .frame(maxWidth: .infinity, minHeight: 44).background(Q.texte, in: .capsule)
        }
        .buttonStyle(StyleAppui())
    }

    private func boutonSombre(_ titre: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titre).font(.system(size: 17)).foregroundStyle(Q.texte)
                .frame(maxWidth: .infinity, minHeight: 44).background(Q.rond, in: .capsule)
        }
        .buttonStyle(StyleAppui())
    }

    private func basculer(_ i: Int) {
        if cases.contains(i) { cases.remove(i) } else { cases.insert(i) }
    }

    private func repondreIndex(_ i: Int) { envoyer(ReponseDialogue(id: dialogue.id, index: max(i, 0))) }

    private func envoyerLibre() {
        let t = libre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        envoyer(ReponseDialogue(id: dialogue.id, index: dialogue.saisie, texte: t))
    }

    private func envoyer(_ r: ReponseDialogue) {
        envoi = true
        Task {
            if let e = await modele.repondre(r, a: session.id) { erreur(e) }
            envoi = false
        }
    }
}
#endif
