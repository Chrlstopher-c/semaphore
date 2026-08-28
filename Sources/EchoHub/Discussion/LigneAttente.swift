// Ce qui partira dès que le tour en cours sera fini.
//
// `☠` Sans cette ligne, le texte mis en attente serait invisible : le champ est
// vidé à l'appui, et Chris croirait avoir envoyé — ou avoir perdu — sa question.
// Une file d'attente muette est pire qu'un refus franc.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct LigneAttente: View {
    @Environment(Salon.self) private var salon

    var body: some View {
        if let attendu = salon.enAttente {
            HStack(spacing: Trame.serre) {
                Image(systemName: "clock").imageScale(.small).foregroundStyle(Teinte.encreEteinte)
                Text(attendu).legende().foregroundStyle(Teinte.encreDouce).lineLimit(1)
                Spacer(minLength: 0)
                Button("Annuler") { salon.annulerAttente() }
                    .buttonStyle(.appui)
                    .legende()
                    .foregroundStyle(Teinte.accent)
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.vertical, Trame.fin)
            .transition(.scene)
        }
    }
}
#endif
