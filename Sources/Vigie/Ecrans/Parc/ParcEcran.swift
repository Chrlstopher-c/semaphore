// Le parc : chaque machine, son état mesuré, ses sessions ouvertes ; réveil (Wake-on-LAN) et extinction.
// Cet écran sert à voir si une machine peut travailler ; l'élément dominant est la carte de chaque machine.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ParcEcran: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.palette) private var p
    @State private var aEteindre: Machine?
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espace.l) {
                EnTeteEcran(surtitre: "machines", titre: "Le parc")
                if let message { BandeauErreur(texte: message) { self.message = nil }.padding(.horizontal, Espace.marge) }
                ForEach(modele.machines) { m in
                    CarteMachine(machine: m, sessions: modele.sessions.filter { $0.machine == m.id && $0.ouverte }.count,
                                 reveil: modele.reveilPossible.contains(m.id),
                                 reveiller: { Task { message = await modele.reveiller(m.id) ?? "Réveil envoyé à \(m.id)." } },
                                 eteindre: { aEteindre = m })
                        .padding(.horizontal, Espace.marge)
                }
            }
            .padding(.bottom, Espace.xxl)
        }
        .background(p.fond.ignoresSafeArea())
        .confirmationDialog(titreExtinction, isPresented: Binding(get: { aEteindre != nil }, set: { if !$0 { aEteindre = nil } }),
                            titleVisibility: .visible) {
            Button("Éteindre", role: .destructive) {
                guard let m = aEteindre else { return }
                Task { message = await modele.eteindre(m.id) ?? "Extinction demandée à \(m.id)." }
            }
        } message: { Text(avertissement) }
    }

    private var titreExtinction: String { "Éteindre \(aEteindre?.id ?? "") ?" }

    private var avertissement: String {
        guard let m = aEteindre else { return "" }
        let n = modele.sessions.filter { $0.machine == m.id && $0.ouverte }.count
        return n > 0 ? "\(n) session(s) Claude y sont ouvertes : elles seront coupées (reprenables)." : "Aucune session Claude n’y est ouverte."
    }
}

struct CarteMachine: View {
    @Environment(\.palette) private var p
    let machine: Machine
    let sessions: Int
    let reveil: Bool
    let reveiller: () -> Void
    let eteindre: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Espace.m) {
            HStack(spacing: Espace.s) {
                PointEtat(ton: machine.enLigne ? .calme : .eteint)
                Text(machine.id).font(Voix.titre).tracking(-0.5).foregroundStyle(p.encre)
                Spacer()
                if sessions > 0 { Pastille(texte: "\(sessions) session\(sessions > 1 ? "s" : "")") }
            }
            Text(machine.description).font(Voix.petit).foregroundStyle(p.discret)
            if machine.enLigne, let e = machine.etat { mesures(e) } else {
                Text("Hors ligne · vue \(Format.depuis(machine.derniereVue))").font(Voix.petit).foregroundStyle(p.discret)
            }
            HStack {
                if !machine.enLigne && reveil { Button("Réveiller", action: reveiller).buttonStyle(StyleBoutonPlein()) }
                if machine.enLigne { Button("Éteindre", action: eteindre).buttonStyle(StyleBoutonDiscret(danger: true)) }
            }
        }
        .carte()
    }

    private func mesures(_ e: EtatMachine) -> some View {
        VStack(spacing: Espace.m) {
            Mesure(libelle: "Processeur", detail: "\(Int(e.cpu.rounded())) % · charge \(String(format: "%.1f", e.charge))", valeur: e.cpu / 100)
            Mesure(libelle: "Mémoire", detail: "\(Format.octets(e.memoire.utilisee)) / \(Format.octets(e.memoire.totale))", valeur: e.memoire.ratio)
            Mesure(libelle: "Disque", detail: "\(Format.octets(e.disque.utilise)) / \(Format.octets(e.disque.total))", valeur: e.disque.ratio)
            Text("allumée depuis \(Format.duree(secondes: e.demarreeDepuis))").font(Voix.etiquette).foregroundStyle(p.discret)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct Mesure: View {
    @Environment(\.palette) private var p
    let libelle: String
    let detail: String
    let valeur: Double

    var body: some View {
        VStack(spacing: Espace.xs) {
            HStack {
                Text(libelle).font(Voix.petit.weight(.bold)).foregroundStyle(p.encreDouce)
                Spacer()
                Text(detail).font(Voix.chiffre).foregroundStyle(p.discret).monospacedDigit()
            }
            Jauge(valeur: valeur, alerte: 0.9)
        }
    }
}
#endif
