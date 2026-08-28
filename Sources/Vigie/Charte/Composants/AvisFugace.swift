// L'avis fugace : la confirmation d'un geste dont le résultat n'a pas besoin
// de rester à l'écran. Tout ce qui doit être RELU (refus métier, conduite)
// passe par `BandeauNote`, en place — jamais par un toast.
#if canImport(SwiftUI)
import SwiftUI

extension View {
    public func avisFugace(_ message: Binding<String?>) -> some View {
        modifier(AvisFugaceModifier(message: message))
    }
}

private struct AvisFugaceModifier: ViewModifier {
    @Binding var message: String?
    @State private var extinction: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    capsule(message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Elan.pose, value: message)
            .onChange(of: message) { _, nouveau in
                programmerExtinction(nouveau)
            }
    }

    private func capsule(_ texte: String) -> some View {
        Text(texte)
            .note()
            .foregroundStyle(Teinte.encre)
            .lineLimit(3)
            .padding(.horizontal, Trame.bloc)
            .padding(.vertical, Trame.element)
            .background(Teinte.surfaceHaute, in: Capsule())
            .overlay(Capsule().strokeBorder(Teinte.filetAppuye, lineWidth: Trame.trait))
            .padding(.horizontal, Trame.ecran)
            .padding(.bottom, Trame.element)
    }

    private func programmerExtinction(_ nouveau: String?) {
        extinction?.cancel()
        guard nouveau != nil else { return }
        extinction = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            message = nil
        }
    }
}
#endif
