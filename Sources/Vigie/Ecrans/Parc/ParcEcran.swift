// Le parc en liste groupée : une section par machine, ses jauges système, et son alimentation (réveil, extinction).
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ParcEcran: View {
    @Environment(ModeleRelais.self) private var modele
    @State private var aEteindre: Machine?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let message { Section { Text(message).font(.footnote).foregroundStyle(.secondary) } }
                ForEach(modele.machines) { m in
                    SectionMachine(machine: m, sessions: modele.sessions.filter { $0.machine == m.id && $0.ouverte && m.enLigne }.count,
                                   reveil: modele.reveilPossible.contains(m.id),
                                   reveiller: { Task { message = await modele.reveiller(m.id) ?? "Réveil envoyé à \(m.id)." } },
                                   eteindre: { aEteindre = m })
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Parc")
            .refreshable { modele.arreter(); modele.demarrer() }
            .confirmationDialog("Éteindre \(aEteindre?.id ?? "") ?", isPresented: Binding(get: { aEteindre != nil },
                                set: { if !$0 { aEteindre = nil } }), titleVisibility: .visible) {
                Button("Éteindre", role: .destructive) {
                    guard let m = aEteindre else { return }
                    Task { message = await modele.eteindre(m.id) ?? "Extinction demandée à \(m.id)." }
                }
            } message: { Text("Les sessions Claude ouvertes dessus seront coupées (reprenables).") }
        }
    }
}

private struct SectionMachine: View {
    let machine: Machine
    let sessions: Int
    let reveil: Bool
    let reveiller: () -> Void
    let eteindre: () -> Void

    var body: some View {
        Section {
            if machine.enLigne, let e = machine.etat {
                Jauge(libelle: "Processeur", detail: "\(Int(e.cpu.rounded())) %", valeur: e.cpu / 100)
                Jauge(libelle: "Mémoire", detail: "\(Format.octets(e.memoire.utilisee)) / \(Format.octets(e.memoire.totale))", valeur: e.memoire.ratio)
                Jauge(libelle: "Disque", detail: "\(Format.octets(e.disque.utilise)) / \(Format.octets(e.disque.total))", valeur: e.disque.ratio)
                LabeledContent("Allumée depuis", value: Format.duree(secondes: e.demarreeDepuis))
                Button("Éteindre", role: .destructive, action: eteindre)
            } else {
                LabeledContent("Vue", value: Format.depuis(machine.derniereVue))
                if reveil { Button("Réveiller", action: reveiller) }
            }
        } header: {
            HStack(spacing: 6) {
                Circle().fill(machine.enLigne ? Color.green : Color(.tertiaryLabel)).frame(width: 8, height: 8)
                Text(machine.id)
                Spacer()
                if sessions > 0 { Text("\(sessions) session\(sessions > 1 ? "s" : "")") }
            }
        } footer: { Text(machine.description) }
    }
}

private struct Jauge: View {
    let libelle: String
    let detail: String
    let valeur: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(libelle, value: detail)
            Gauge(value: min(max(valeur, 0), 1)) {} currentValueLabel: {}
                .gaugeStyle(.accessoryLinearCapacity).tint(valeur >= 0.9 ? .red : Charte.accent)
        }
    }
}
#endif
