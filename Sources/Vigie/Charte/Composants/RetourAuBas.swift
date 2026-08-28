// La pastille « redescendre » : posée en surimpression d'un défilement long,
// elle ramène au dernier élément d'un geste.
//
// Neutre par charte — surface haute et filet, jamais l'orange accent : redescendre
// dans un fil qu'on lit n'est pas un geste qui engage.
#if canImport(SwiftUI)
import SwiftUI

public struct RetourAuBas: View {
    private let intitule: String
    private let sauter: () -> Void
    @State private var appuis = 0

    public init(intitule: String = "Aller au dernier message", sauter: @escaping () -> Void) {
        self.intitule = intitule
        self.sauter = sauter
    }

    public var body: some View {
        Button {
            appuis += 1
            sauter()
        } label: {
            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Teinte.encre)
                .frame(width: 36, height: 36)
                .background(Teinte.surfaceHaute, in: Circle())
                .overlay(Circle().strokeBorder(Teinte.filetAppuye, lineWidth: Trame.trait))
                // L'ombre porte la pastille au-dessus du texte qui défile
                // dessous : sans elle, elle se confond avec un bloc de code.
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        }
        .buttonStyle(.allureIcone)
        .sensoryFeedback(Haptique.contact, trigger: appuis)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel(intitule)
    }
}
#endif
