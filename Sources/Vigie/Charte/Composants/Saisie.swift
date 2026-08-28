// Congédier le clavier, présenter une feuille — les deux idiomes de saisie de
// la charte.
//
// `☠` SwiftUI ne ferme un clavier sur AUCUN geste par défaut : sans ces
// issues, le clavier masque la moitié de l'écran et rien ne le renvoie.
#if canImport(SwiftUI)
import SwiftUI
import UIKit

public enum ClavierQuart {
    /// Retire le premier répondeur, quel qu'il soit. UIKit, parce que
    /// `@FocusState` est local à une vue et que le clavier, lui, est global.
    @MainActor
    public static func fermer() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}

extension View {
    /// À poser sur tout écran défilant qui porte un champ. Le toucher est capté
    /// par un fond transparent : un `onTapGesture` sur le contenu volerait les
    /// touchers destinés aux boutons.
    public func rendLeClavier() -> some View {
        background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture { ClavierQuart.fermer() }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Variante des surfaces qui ne défilent pas (feuilles courtes).
    public func rendLeClavierSansDefilement() -> some View {
        background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture { ClavierQuart.fermer() }
        }
    }

    /// La feuille de la charte : hauteurs multiples, poignée, coins francs,
    /// fond de surface haute. Une modale plein écran pour trois lignes est un
    /// réflexe web.
    public func feuilleQuart<Contenu: View>(
        presentee: Binding<Bool>,
        hauteurs: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder contenu: @escaping () -> Contenu
    ) -> some View {
        sheet(isPresented: presentee) {
            contenu()
                .presentationDetents(hauteurs)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackground(Teinte.surfaceHaute)
        }
    }
}
#endif
