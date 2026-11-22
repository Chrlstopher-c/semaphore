// Les appareils du parc, à la place de la capsule « + Add device » de l'étalon : une capsule par machine, même dessin
// (liseré 1 pt, fond presque noir), glyphe vert en ligne. Toucher : réveiller ou éteindre.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct BandeAppareils: View {
    @Environment(ModeleRelais.self) private var modele
    @State private var aEteindre: Machine?
    @State private var erreur: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if modele.machines.isEmpty { capsule(symbole: "plus", titre: "Aucun appareil", couleur: Q.texte) }
                ForEach(modele.machines) { m in
                    Menu { actions(m) } label: {
                        capsule(symbole: symbole(m), titre: m.id, couleur: m.enLigne ? Q.enLigne : Q.meta)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .confirmationDialog("Éteindre \(aEteindre?.id ?? "") ?", isPresented: confirmation, titleVisibility: .visible) {
            Button("Éteindre", role: .destructive) { if let m = aEteindre { lancer { await modele.eteindre(m.id) } } }
        } message: { Text("Les sessions de cette machine s’arrêteront.") }
        .alert("Commande refusée", isPresented: Binding(get: { erreur != nil }, set: { if !$0 { erreur = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(erreur ?? "") }
    }

    private var confirmation: Binding<Bool> {
        Binding(get: { aEteindre != nil }, set: { if !$0 { aEteindre = nil } })
    }

    @ViewBuilder private func actions(_ m: Machine) -> some View {
        Text(m.enLigne ? "En ligne" : "Hors ligne")
        if !m.enLigne && modele.reveilPossible.contains(m.id) {
            Button("Réveiller", systemImage: "power") { lancer { await modele.reveiller(m.id) } }
        }
        if m.enLigne {
            Button("Éteindre…", systemImage: "power", role: .destructive) { aEteindre = m }
        }
    }

    private func lancer(_ commande: @escaping @MainActor () async -> String?) {
        Task { erreur = await commande() }
    }

    private func capsule(symbole: String, titre: String, couleur: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbole).font(.system(size: 15)).foregroundStyle(couleur)
            Text(titre).font(Q.rangee).foregroundStyle(Q.texte)
        }
        .padding(.horizontal, 16).frame(height: 42)
        .background(Color(hex: 0x0D0D0D), in: .capsule)
        .overlay(Capsule().strokeBorder(Q.lisere))
    }

    private func symbole(_ m: Machine) -> String {
        let nom = (m.id + " " + m.description).lowercased()
        if nom.contains("portable") { return "laptopcomputer" }
        if m.id == "pi" || nom.contains(" pi") { return "cpu" }
        return "desktopcomputer"
    }
}
#endif
