// Ce qu'on peut faire d'un message déjà écrit : le copier, le rejouer, le
// modifier, passer à une autre variante.
//
// `☠` Règle reprise du web mot pour mot : un bouton indisponible est DÉSACTIVÉ
// et dit pourquoi — il ne disparaît pas. Une entrée qui s'évapore laisse croire
// à un bug ; une flèche grisée dit « il n'y a rien de ce côté ».
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau
#if canImport(UIKit)
import UIKit
#endif

/// La rangée d'actions sous une réponse du modèle.
struct ActionsReponse: View {
    @Environment(Salon.self) private var salon
    let message: MessageChat

    var body: some View {
        HStack(spacing: Trame.element) {
            NavigationVariantes(message: message)
            BoutonAction("Copier", symbole: "doc.on.doc") {
                Presse.poser(SegmenteurReponse.segmenter(message.contenu).visible)
            }
            BoutonAction("Rejouer", symbole: "arrow.clockwise") { salon.rejouer(message) }
                .disabled(salon.enGeneration)
            Spacer(minLength: 0)
        }
    }
}

/// Les actions sous une question de Chris. Modifier ouvre une branche sœur —
/// l'ancienne question et sa réponse restent dans l'arbre du PC.
struct ActionsQuestion: View {
    @Environment(Salon.self) private var salon
    let message: MessageChat
    let surModification: (MessageChat) -> Void

    var body: some View {
        HStack(spacing: Trame.element) {
            Spacer(minLength: 0)
            NavigationVariantes(message: message)
            BoutonAction("Copier", symbole: "doc.on.doc") { Presse.poser(message.contenu) }
            BoutonAction("Modifier", symbole: "pencil") { surModification(message) }
                // Un message encore porteur de son identifiant provisoire
                // n'existe pas côté PC : l'éditer rendrait un 404.
                .disabled(salon.enGeneration || Salon.estLocal(message.id))
        }
    }
}

/// « ‹ 2 / 3 › ». Absente quand le tour n'a qu'une version : un « 1 / 1 »
/// n'apprend rien et occupe une rangée sur 375 pt.
struct NavigationVariantes: View {
    @Environment(Salon.self) private var salon
    let message: MessageChat

    var body: some View {
        if let position = salon.positionVariante(de: message) {
            HStack(spacing: Trame.fin) {
                fleche("chevron.left", decalage: -1)
                Text("\(position.rang) / \(position.total)")
                    .mesureFine()
                    .foregroundStyle(Teinte.encreDouce)
                fleche("chevron.right", decalage: 1)
            }
        }
    }

    private func fleche(_ symbole: String, decalage: Int) -> some View {
        let cible = salon.variante(de: message, decalage: decalage)
        return Button {
            guard let cible else { return }
            Task { await salon.afficherVariante(cible) }
        } label: {
            Image(systemName: symbole).imageScale(.small)
        }
        .buttonStyle(.appui)
        .foregroundStyle(cible == nil ? Teinte.encreEteinte : Teinte.accent)
        .disabled(cible == nil || salon.enGeneration)
        .accessibilityLabel(decalage < 0 ? "Variante précédente" : "Variante suivante")
    }
}

/// Un verbe discret sous un message. Jamais l'accent plein : ces actions
/// servent le texte, elles ne se disputent pas l'œil avec lui.
struct BoutonAction: View {
    private let libelle: String
    private let symbole: String
    private let action: () -> Void
    @State private var joue = 0

    init(_ libelle: String, symbole: String, action: @escaping () -> Void) {
        self.libelle = libelle
        self.symbole = symbole
        self.action = action
    }

    var body: some View {
        Button {
            joue += 1
            action()
        } label: {
            HStack(spacing: Trame.fin) {
                Image(systemName: symbole).imageScale(.small)
                Text(libelle)
            }
            .legende()
            .contentShape(.rect)
        }
        .buttonStyle(.appui)
        .foregroundStyle(Teinte.encreDouce)
        .sensoryFeedback(Retour.engage, trigger: joue)
        .accessibilityLabel(libelle)
    }
}

/// Le presse-papier, en un seul endroit.
///
/// `☠` Il n'existait AUCUN bouton copier dans l'app. `textSelection` est posé,
/// donc la sélection manuelle marche — mais sélectionner trente lignes de code
/// au doigt n'est pas un geste.
enum Presse {
    static func poser(_ texte: String) {
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !propre.isEmpty else { return }
        #if canImport(UIKit)
        UIPasteboard.general.string = propre
        #else
        Journal.note("presse-papier indisponible sur cette plateforme")
        #endif
    }
}
#endif
