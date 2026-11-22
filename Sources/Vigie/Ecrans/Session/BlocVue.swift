// Un bloc du fil : bulle de Chris, réponse (markdown + copier / lire), ligne résumée d'une suite d'actions, jalons.
#if canImport(SwiftUI)
import AVFoundation
import SwiftUI
import VigieNoyau

struct BlocVue: View {
    let bloc: BlocFil
    let ouvrirActions: (GroupeActions) -> Void

    var body: some View {
        switch bloc {
        case .utilisateur(_, let texte): BulleChris(texte: texte)
        case .assistant(_, let texte): Reponse(texte: texte)
        case .actions(let groupe): LigneActions(groupe: groupe) { ouvrirActions(groupe) }
        case .autre(let element): AutreElement(element: element)
        }
    }
}

/// Bulle de Chris (étalon 023) : à droite, #1F1F1E, rayon 22, de x 61 à 359.
private struct BulleChris: View {
    let texte: String

    var body: some View {
        HStack {
            Spacer(minLength: 40)
            Text(texte).font(Q.corpsFil).foregroundStyle(Q.texteBulle).lineSpacing(Q.interligneFil)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Q.bulle, in: .rect(cornerRadius: 22, style: .continuous))
                .contextMenu { Button("Copier", systemImage: "square.on.square") { UIPasteboard.general.string = texte } }
        }
        .padding(.trailing, -8) // étalon : la bulle s'arrête à 16 pt du bord, le texte des réponses à 24
    }
}

/// Réponse de Claude : texte pleine largeur, puis copier et lire à voix haute (glyphes gris de l'étalon).
private struct Reponse: View {
    let texte: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarkdownVue(source: texte)
            HStack(spacing: 4) {
                BoutonCopier(texte: texte)
                Button { Lecteur.partage.lire(texte) } label: {
                    Image(systemName: "play").font(.system(size: 15)).foregroundStyle(Q.tertiaire)
                        .frame(width: 40, height: 40).contentShape(.rect)
                }
                .accessibilityLabel("Lire à voix haute")
            }
            .padding(.leading, -12)
        }
        .contextMenu { Button("Copier", systemImage: "square.on.square") { UIPasteboard.general.string = texte } }
    }
}

/// Lecture à voix haute d'une réponse, en français. Un second appui arrête.
@MainActor final class Lecteur {
    static let partage = Lecteur()
    private let voix = AVSpeechSynthesizer()

    func lire(_ texte: String) {
        if voix.isSpeaking { voix.stopSpeaking(at: .immediate); return }
        let phrase = AVSpeechUtterance(string: texte)
        phrase.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        voix.speak(phrase)
    }
}

/// « Exécuté 2 commandes, créé 1 fichier › » — toucher ouvre la feuille de la suite (étalon 022/023).
private struct LigneActions: View {
    let groupe: GroupeActions
    let ouvrir: () -> Void

    var body: some View {
        Button(action: ouvrir) {
            HStack(spacing: 8) {
                if groupe.enCours { IndicateurTravail().frame(width: 14, height: 14) }
                Text(libelle).font(Q.detail).foregroundStyle(Q.tertiaire).lineLimit(1)
                if groupe.echecs > 0 {
                    Text(groupe.echecs > 1 ? "· \(groupe.echecs) ont échoué" : "· 1 a échoué").font(Q.detail)
                        .foregroundStyle(Q.retraitTexte)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundStyle(Q.meta)
            }
            .frame(minHeight: 32).contentShape(.rect)
        }
        .buttonStyle(StyleAppui())
    }

    private var libelle: String {
        guard groupe.enCours, case .outil(let o)? = groupe.elements.last(where: { if case .outil = $0 { true } else { false } }),
              o.resultat == nil else { return groupe.resume }
        return ResumeOutils.intituleEnCours(nom: o.nom, entree: o.detail)
    }
}
#endif
