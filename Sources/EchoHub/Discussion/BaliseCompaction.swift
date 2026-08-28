// La balise d'une compaction de contexte, posée dans le fil au-dessus du
// message assistant dont la génération l'a déclenchée.
//
// `☠` Même vocabulaire visuel que `BlocReplie` : un bloc repliable en registre
// `note`, sur `surface`, avec son chevron. Ce n'est pas la réponse du modèle —
// c'est un cheminement de la machine, il recule et ne se dispute jamais l'œil
// avec l'encre. Replié, une ligne dit le poids (« N messages résumés ·
// avant→après ») ; déplié, il montre le résumé que le moteur relit à la place
// des tours anciens. Aucune couleur ni taille en dur — jetons de charte seuls.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct BaliseCompaction: View {
    let info: InfoCompaction
    @State private var deplie = false

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Button(action: basculer) { entete }
                .buttonStyle(.appui)
            if deplie {
                Text(info.resume)
                    .registre(.note)
                    .selonRegistre()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.scene)
            }
        }
        .padding(Trame.element)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Teinte.surface)
        .clipShape(.rect(cornerRadius: Galbe.carte, style: .continuous))
        .animation(Elan.surface, value: deplie)
    }

    private var entete: some View {
        HStack(spacing: Trame.serre) {
            Text("🗜")
            Text(ligne).note().foregroundStyle(Teinte.encreDouce)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .imageScale(.small)
                .foregroundStyle(Teinte.encreEteinte)
                .rotationEffect(.degrees(deplie ? 0 : -90))
        }
        .contentShape(.rect)
    }

    /// La ligne repliée : ce que la balise dit sans qu'on l'ouvre. En milliers,
    /// comme `LigneContexte` — sur une fenêtre de plusieurs dizaines de k, les
    /// derniers chiffres ne décident de rien et font danser la largeur.
    private var ligne: String {
        "Contexte compacté — \(messagesResumes) · \(milliers(info.tokensAvant)) → \(milliers(info.tokensApres))"
    }

    private var messagesResumes: String {
        let n = info.nbMessagesResumes
        return n <= 1 ? "\(n) message résumé" : "\(n) messages résumés"
    }

    private func milliers(_ tokens: Int) -> String { "\(tokens / 1000) k" }

    private func basculer() {
        withAnimation(Elan.surface) { deplie.toggle() }
    }
}
#endif
