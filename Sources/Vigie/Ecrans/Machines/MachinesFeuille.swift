// Les machines du parc, dans la grammaire de l'étalon (feuille, ✕ à gauche, cartes groupées #20201F) : une rangée
// par machine (glyphe vert en ligne, état, dernière activité), puis la page d'une machine : actions (réveiller,
// éteindre, nouvelle session, fichiers, terminal) et ses sessions. Fichiers et terminal : écrans gardés de Vigie.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct MachinesFeuille: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.dismiss) private var fermer
    let ouvrirSession: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    TitreSection(texte: "Parc")
                    Carte {
                        if modele.machines.isEmpty {
                            RangeeReglage(titre: "Aucune machine", couleur: Q.tertiaire, chevron: false)
                        }
                        ForEach(Array(modele.machines.enumerated()), id: \.offset) { i, m in
                            if i > 0 { Filet(retrait: 60) }
                            NavigationLink(value: m.id) { RangeeMachine(machine: m) }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .barreFeuille("Machines")
            .toolbar { ToolbarItem(placement: .topBarLeading) { BoutonEntete(symbole: "xmark") { fermer() } } }
            .navigationDestination(for: String.self) { MachineEcran(id: $0, ouvrirSession: ouvrirSession) }
            .navigationDestination(for: EmplacementDistant.self) { DossierEcran(lieu: $0) }
            .navigationDestination(for: FichierDistant.self) { FichierEcran(fichier: $0) }
            .navigationDestination(for: CibleTerminal.self) { TerminalEcran(cible: $0) }
        }
        .feuilleQuart([.large])
    }
}

/// Glyphe d'une machine d'après son nom (portable, Pi, tour ou autre).
enum GlypheMachine {
    static func symbole(_ m: Machine) -> String {
        let nom = (m.id + " " + m.description).lowercased()
        if nom.contains("portable") || nom.contains("laptop") { return "laptopcomputer" }
        if m.id == "pi" || nom.contains("raspberry") || nom.hasPrefix("pi ") { return "cpu" }
        return "desktopcomputer"
    }
}

private struct RangeeMachine: View {
    @Environment(ModeleRelais.self) private var modele
    let machine: Machine

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: GlypheMachine.symbole(machine)).font(.system(size: 19, weight: .light))
                .foregroundStyle(machine.enLigne ? Q.enLigne : Q.meta).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(machine.id).font(Q.rangee).foregroundStyle(Q.texte)
                Text(detail).font(Q.detail).foregroundStyle(Q.secondaire).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium)).foregroundStyle(Q.meta)
        }
        .padding(.horizontal, Q.marge).frame(minHeight: 60).contentShape(.rect)
    }

    private var detail: String {
        let n = modele.sessions.filter { $0.machine == machine.id && $0.archivee != true && $0.statut.enActivite }.count
        let etat = EtatAppareil.texte(machine, maintenant: .now)
        return machine.enLigne && n > 0 ? "\(etat) · \(n) au travail" : etat
    }
}

private struct MachineEcran: View {
    @Environment(ModeleRelais.self) private var modele
    let id: String
    let ouvrirSession: (String) -> Void
    @State private var erreur: String?
    @State private var aEteindre = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let m = modele.machine(id) { contenu(m) }
            }
            .padding(.bottom, 24)
        }
        .barreFeuille(id)
        .confirmationDialog("Éteindre \(id) ?", isPresented: $aEteindre, titleVisibility: .visible) {
            Button("Éteindre", role: .destructive) { lancer { await modele.eteindre(id) } }
        } message: { Text("Les sessions de cette machine s’arrêteront.") }
    }

    @ViewBuilder private func contenu(_ m: Machine) -> some View {
        Carte {
            RangeeReglage(symbole: GlypheMachine.symbole(m), titre: m.enLigne ? "En ligne" : "Hors ligne",
                          valeur: m.enLigne ? nil : EtatAppareil.texte(m, maintenant: .now)
                            .replacingOccurrences(of: "Hors ligne · ", with: ""),
                          couleur: m.enLigne ? Q.enLigne : Q.texte, chevron: false)
        }
        .padding(.top, 8)
        if let erreur {
            Text(erreur).font(Q.detail).foregroundStyle(Q.retraitTexte).padding(.horizontal, 32).padding(.top, 8)
        }
        TitreSection(texte: "Actions")
        Carte { actions(m) }
        SessionsMachine(id: id, ouvrirSession: ouvrirSession)
    }

    @ViewBuilder private func actions(_ m: Machine) -> some View {
        if !m.enLigne && modele.reveilPossible.contains(m.id) {
            bouton("power", "Réveiller") { lancer { await modele.reveiller(m.id) } }
            Filet(retrait: 60)
        }
        NavigationLink(value: EmplacementDistant(machine: m.id, chemin: nil)) {
            RangeeReglage(symbole: "folder", titre: "Fichiers")
        }
        .buttonStyle(.plain).disabled(!m.enLigne)
        Filet(retrait: 60)
        NavigationLink(value: CibleTerminal(machine: m.id, titre: "\(m.id) · terminal")) {
            RangeeReglage(symbole: "apple.terminal", titre: "Terminal")
        }
        .buttonStyle(.plain).disabled(!m.enLigne)
        if m.enLigne {
            Filet(retrait: 60)
            bouton("power", "Éteindre…", couleur: Q.deconnexion) { aEteindre = true }
        }
    }

    private func bouton(_ symbole: String, _ titre: String, couleur: Color = Q.texte,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) { RangeeReglage(symbole: symbole, titre: titre, couleur: couleur, chevron: false) }
            .buttonStyle(.plain)
    }

    private func lancer(_ commande: @escaping @MainActor () async -> String?) {
        Task { erreur = await commande() }
    }
}

/// Les sessions de la machine, en lignes de la liste Code ; toucher ferme la feuille et ouvre la session.
private struct SessionsMachine: View {
    @Environment(ModeleRelais.self) private var modele
    let id: String
    let ouvrirSession: (String) -> Void

    var body: some View {
        let sessions = JumellesDistantes.sansDoublons(modele.sessions).filter { $0.machine == id }
        let lignes = ListeSessions.lignes(sessions, machines: modele.machines, maintenant: .now,
                                          premiersMessages: modele.premiersMessages)
        if !lignes.isEmpty {
            TitreSection(texte: "Sessions")
            VStack(spacing: 0) {
                ForEach(lignes.prefix(30)) { l in
                    Button { ouvrirSession(l.id) } label: { LigneSessionVue(ligne: l) }.buttonStyle(StyleAppui())
                }
            }
        }
    }
}
#endif
