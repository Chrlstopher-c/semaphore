// Renommer une session : la boîte système à champ, comme l'entrée « Rename » de l'étalon.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

private struct Renommage: ViewModifier {
    @Environment(ModeleRelais.self) private var modele
    @Binding var session: Session?
    @Binding var bandeau: String?
    @State private var titre = ""

    func body(content: Content) -> some View {
        content
            .alert("Renommer la session", isPresented: presente) {
                TextField("Titre", text: $titre)
                Button("Annuler", role: .cancel) {}
                Button("Renommer") { valider() }
            }
            .onChange(of: session?.id) { _, _ in titre = session?.titre ?? "" }
    }

    private var presente: Binding<Bool> {
        Binding(get: { session != nil }, set: { if !$0 { session = nil } })
    }

    private func valider() {
        guard let id = session?.id else { return }
        let propre = titre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !propre.isEmpty else { return }
        Task { if let e = await modele.renommer(propre, de: id) { bandeau = e } }
    }
}

extension View {
    func renommage(session: Binding<Session?>, bandeau: Binding<String?>) -> some View {
        modifier(Renommage(session: session, bandeau: bandeau))
    }
}
#endif
