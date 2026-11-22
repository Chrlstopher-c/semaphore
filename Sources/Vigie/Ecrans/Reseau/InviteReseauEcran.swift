// Réglages › Réseau › un invité › Limites et accès : modèles et effort maximal, parts des limites 5 h et hebdo,
// sessions simultanées, machines où ses sessions tournent, prompt imposé, accès, télémétrie et activité du jour.
// Les réglages se modifient ici puis partent d'un coup (« Enregistrer ») : une seule charte signée par cet iPhone.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct InviteReseauEcran: View {
    let modele: ModeleReseau
    let id: String
    @State private var reglages: ReglagesInvite?
    @State private var activite: ActiviteInvite?

    private var membre: MembreCharte? { modele.charte?.membre(id) }
    private var gele: Bool { !modele.chef || modele.enCours != nil }
    private var modifie: Bool { reglages != nil && reglages != membre?.invite }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if reglages != nil { formulaire }
            }
            .padding(.bottom, 32)
        }
        .barreFeuille(membre?.nom ?? "Invité")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Enregistrer") { enregistrer() }.disabled(!modifie || gele).tint(Q.lien)
            }
        }
        .task {
            if reglages == nil { reglages = membre?.invite }
            activite = await modele.activite(id)
        }
    }

    private var lien: Binding<ReglagesInvite> {
        Binding(get: { reglages ?? .parDefaut(machine: nil) }, set: { reglages = $0 })
    }

    @ViewBuilder private var formulaire: some View {
        BandeauErreurReseau(modele: modele).padding(.top, 8)
        ModelesInvite(reglages: lien, gele: gele)
        LimitesInvite(reglages: lien, gele: gele)
        MachinesInvite(reglages: lien, machines: machinesPermises, gele: gele)
        TitreSection(texte: "Prompt imposé")
        Carte {
            TextEditor(text: lien.prompt).font(Q.corps).foregroundStyle(Q.texte).scrollContentBackground(.hidden)
                .frame(minHeight: 110).padding(.horizontal, 12).padding(.vertical, 8).disabled(gele)
        }
        Note(texte: "Ajouté en dernier à chaque session de l’invité, après le sien.")
        AccesInviteVue(reglages: lien, gele: gele)
        ActiviteInviteVue(reglages: lien, activite: activite, gele: gele)
    }

    /// Les machines où ses sessions peuvent tourner : membres serveur ou pair, non invités.
    private var machinesPermises: [MembreCharte] {
        (modele.charte?.membres ?? []).filter { $0.invite == nil && $0.sorte != .telephone }
    }

    private func enregistrer() {
        guard let fixes = reglages else { return }
        let id = id
        Task {
            await modele.editer("Signature…") { c, moi, le in
                try EditionCharte.changerInvite(c, auteur: moi, membre: id, reglages: fixes, le: le)
            }
        }
    }
}

/// Un interrupteur de réglage, à la hauteur des rangées.
private struct Interrupteur: View {
    let titre: String
    let valeur: Binding<Bool>
    var gele = false

    var body: some View {
        Toggle(isOn: valeur) { Text(titre).font(Q.rangee).foregroundStyle(gele ? Q.tertiaire : Q.texte) }
            .tint(Q.coche).padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur).disabled(gele)
    }
}

/// Un choix en menu, à droite de son libellé (grammaire de Claude Code dans les réglages).
private struct Choix<Valeur: Hashable>: View {
    let titre: String
    let valeur: Binding<Valeur>
    let options: [(Valeur, String)]
    var gele = false

    var body: some View {
        HStack {
            Text(titre).font(Q.rangee).foregroundStyle(gele ? Q.tertiaire : Q.texte)
            Spacer()
            Picker(titre, selection: valeur) { ForEach(options, id: \.0) { Text($0.1).tag($0.0) } }
                .pickerStyle(.menu).tint(Q.secondaire)
        }
        .padding(.leading, Q.marge).padding(.trailing, 4).frame(height: Q.rangeeHauteur).disabled(gele)
    }
}

/// Modèles permis (une famille absente est interdite) et, pour chacun, l'effort jusqu'auquel il peut monter.
private struct ModelesInvite: View {
    @Binding var reglages: ReglagesInvite
    let gele: Bool

    var body: some View {
        TitreSection(texte: "Modèles")
        Carte {
            ForEach(Array(ReglagesInvite.familles.enumerated()), id: \.element) { rang, famille in
                if rang > 0 { Filet() }
                Interrupteur(titre: famille.capitalized, valeur: permis(famille), gele: gele)
                if reglages.modeles[famille] != nil {
                    Choix(titre: "Effort jusqu’à", valeur: plafond(famille),
                          options: ReglagesInvite.efforts.map { ($0, CatalogueModeles.libelleEffort(
                              EffortSession(rawValue: $0) ?? .medium) ?? $0) }, gele: gele)
                        .padding(.leading, 16)
                }
            }
        }
    }

    private func permis(_ famille: String) -> Binding<Bool> {
        Binding(get: { reglages.modeles[famille] != nil },
                set: { reglages.modeles[famille] = $0 ? Array(ReglagesInvite.efforts.prefix(3)) : nil })
    }

    private func plafond(_ famille: String) -> Binding<String> {
        Binding(get: { reglages.modeles[famille]?.last ?? "high" }, set: { haut in
            let rang = ReglagesInvite.efforts.firstIndex(of: haut) ?? 2
            reglages.modeles[famille] = Array(ReglagesInvite.efforts.prefix(rang + 1))
        })
    }
}

/// Parts des limites du compte (5 h, hebdo) et nombre de sessions simultanées.
private struct LimitesInvite: View {
    @Binding var reglages: ReglagesInvite
    let gele: Bool
    private static let parts = [5, 10, 25, 50, 75, 100]

    var body: some View {
        TitreSection(texte: "Limites")
        Carte {
            Choix(titre: "Part de la limite 5 h", valeur: $reglages.part5h,
                  options: Self.options(reglages.part5h), gele: gele)
            Filet()
            Choix(titre: "Part hebdomadaire", valeur: hebdo,
                  options: [(-1, "Sans plafond")] + Self.options(reglages.partSemaine ?? 25), gele: gele)
            Filet()
            Stepper(value: $reglages.simultanees, in: 1...10) {
                Text("Sessions simultanées : \(reglages.simultanees)").font(Q.rangee).foregroundStyle(Q.texte)
            }
            .padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur).disabled(gele)
        }
        Note(texte: "Comptées sur le compte Claude de la machine qui fait tourner ses sessions.")
    }

    private var hebdo: Binding<Int> {
        Binding(get: { reglages.partSemaine ?? -1 }, set: { reglages.partSemaine = $0 < 0 ? nil : $0 })
    }

    private static func options(_ actuelle: Int) -> [(Int, String)] {
        Array(Set(parts + [actuelle])).sorted().map { ($0, "\($0) %") }
    }
}

/// Machines où ses sessions tournent ; « Sur sa machine » seulement si elle annonce un compte Claude.
private struct MachinesInvite: View {
    @Binding var reglages: ReglagesInvite
    let machines: [MembreCharte]
    let gele: Bool

    var body: some View {
        TitreSection(texte: "Machines")
        Carte {
            ForEach(Array(machines.enumerated()), id: \.element.id) { rang, m in
                if rang > 0 { Filet() }
                Interrupteur(titre: m.nom, valeur: permise(m.id), gele: gele)
            }
            if !machines.isEmpty { Filet() }
            Interrupteur(titre: "Sur sa machine", valeur: $reglages.surSaMachine, gele: gele || !reglages.surSaMachine)
        }
        Note(texte: "Ses sessions tournent sur une machine du réseau : il n’envoie que des messages.")
    }

    private func permise(_ id: String) -> Binding<Bool> {
        Binding(get: { reglages.machines.contains(id) }, set: { oui in
            reglages.machines.removeAll { $0 == id }
            if oui { reglages.machines.append(id) }
        })
    }
}

/// Accès hors de son espace ; les terminaux restent fermés (Claude seulement dans l'appli).
private struct AccesInviteVue: View {
    @Binding var reglages: ReglagesInvite
    let gele: Bool

    var body: some View {
        TitreSection(texte: "Accès")
        Carte {
            Interrupteur(titre: "Remote Control", valeur: $reglages.acces.remoteControl, gele: gele)
            Filet()
            Interrupteur(titre: "Terminaux", valeur: .constant(false), gele: true)
            Filet()
            Interrupteur(titre: "Sessions des autres", valeur: $reglages.acces.sessionsAutres, gele: gele)
            Filet()
            Interrupteur(titre: "Modules", valeur: $reglages.acces.modules, gele: gele)
            Filet()
            Interrupteur(titre: "Fichiers hors de son espace", valeur: $reglages.acces.fichiersHors, gele: gele)
        }
        Note(texte: "Les terminaux restent fermés à un invité : ils liraient les identifiants de la machine.")
    }
}

/// Télémétrie (métadonnées seulement, jamais le contenu) et activité du jour.
private struct ActiviteInviteVue: View {
    @Binding var reglages: ReglagesInvite
    let activite: ActiviteInvite?
    let gele: Bool

    var body: some View {
        TitreSection(texte: "Activité")
        Carte {
            Interrupteur(titre: "Télémétrie", valeur: $reglages.telemetrie, gele: gele)
            if reglages.telemetrie, let a = activite {
                Filet(retrait: 60)
                RangeeReglage(symbole: "clock", titre: "Aujourd’hui", valeur: a.actifAujourdhui ? "Actif" : "Inactif",
                              chevron: false)
                Filet(retrait: 60)
                RangeeReglage(symbole: "bubble.left.and.bubble.right", titre: "Sessions",
                              valeur: "\(a.sessionsEnCours) en cours · \(a.sessionsAujourdhui) aujourd’hui",
                              chevron: false)
                Filet(retrait: 60)
                RangeeReglage(symbole: "number", titre: "Jetons du jour", valeur: "\(a.jetonsAujourdhui)",
                              chevron: false)
                if let p = a.part5h { part("Limite 5 h", p) }
                if let p = a.semaine { part("Semaine", p) }
            }
        }
        Note(texte: "Seulement l’activité : ni titre, ni contenu de ses conversations.")
    }

    private func part(_ titre: String, _ p: PartInvite) -> some View {
        VStack(spacing: 6) {
            Filet(retrait: 60)
            RangeeReglage(symbole: "gauge.with.dots.needle.33percent", titre: titre,
                          valeur: "\(Int(p.consomme.rounded())) % sur \(Int(p.part.rounded())) %", chevron: false)
            Jauge(part: p.part > 0 ? p.consomme / p.part : 0)
                .padding(.leading, 60).padding(.trailing, Q.marge).padding(.bottom, 10)
        }
    }
}
#endif
