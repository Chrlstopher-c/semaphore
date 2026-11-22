// Réglages › Réseau › un membre : état et ressources (machine), droits, compte Claude, rôle de chef, actions machine
// (pause, redémarrer, éteindre, réveiller) et retrait du réseau. Un geste = une charte ou un ordre signé par cet
// iPhone ; non chef, tout se lit et rien ne se touche. Grammaire de la page d'une machine (MachinesFeuille).
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct MembreReseauEcran: View {
    let modele: ModeleReseau
    let id: String
    @State private var confirmation: ConfirmationMembre?

    private var charte: CharteReseau? { modele.charte }
    private var membre: MembreCharte? { charte?.membre(id) }
    private var machine: MachineReseau? { modele.machines.first { $0.membre == id } }
    private var gele: Bool { !modele.chef || modele.enCours != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let membre, let charte { contenu(membre, charte) } else { parti }
            }
            .padding(.bottom, 32)
        }
        .barreFeuille(membre?.nom ?? "Membre")
        .confirmationDialog(confirmation?.titre ?? "", isPresented: confirme, titleVisibility: .visible,
                            presenting: confirmation) { c in
            Button(c.bouton, role: .destructive) { Task { await executer(c) } }
        } message: { c in Text(c.message) }
    }

    private var confirme: Binding<Bool> {
        Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })
    }

    @ViewBuilder private func contenu(_ m: MembreCharte, _ c: CharteReseau) -> some View {
        Carte {
            RangeeReglage(symbole: GlypheMembre.symbole(m), titre: etat,
                          valeur: DetailMembre.role(m, charte: c),
                          couleur: machine?.enLigne == true ? Q.enLigne : Q.texte, chevron: false)
        }
        .padding(.top, 8)
        BandeauErreurReseau(modele: modele)
        if let etat = machine?.etat, machine?.enLigne == true { RessourcesMachine(etat: etat) }
        if m.invite != nil {
            TitreSection(texte: "Invité")
            Carte {
                NavigationLink { InviteReseauEcran(modele: modele, id: id) } label: {
                    RangeeReglage(symbole: "slider.horizontal.3", titre: "Limites et accès")
                }
                .buttonStyle(.plain)
            }
        } else {
            DroitsMembreVue(modele: modele, membre: m, chef: c.estChef(m.id), gele: gele)
        }
        if machine != nil, m.invite == nil { CompteMembreVue(modele: modele, membre: m, machine: machine, gele: gele) }
        if m.sorte != .serveur, m.invite == nil { role(m, c) }
        if let machine { actions(machine) }
        if m.id != modele.moi { retrait(m) }
    }

    private var etat: String {
        guard let machine else { return membre?.sorte == .telephone ? "Téléphone" : "Membre" }
        return machine.enLigne ? "En ligne" : "Hors ligne"
    }

    private func role(_ m: MembreCharte, _ c: CharteReseau) -> some View {
        let estChef = c.estChef(m.id)
        return VStack(spacing: 0) {
            TitreSection(texte: "Rôle")
            Carte {
                Toggle(isOn: Binding(get: { estChef }, set: { nommer($0) })) {
                    Text("Chef du réseau").font(Q.rangee).foregroundStyle(Q.texte)
                }
                .tint(Q.coche).padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur)
                .disabled(gele || m.id == modele.moi)
            }
            Note(texte: m.id == modele.moi
                 ? "Un autre chef peut te retirer ce rôle ; tu ne peux pas te le retirer toi-même."
                 : "Un chef ajoute, retire et règle les membres, et agit sur les machines.")
        }
    }

    private func nommer(_ chef: Bool) {
        Task {
            await modele.editer("Signature…") { c, moi, le in
                try EditionCharte.nommerChef(c, auteur: moi, membre: id, chef: chef, le: le)
            }
        }
    }

    @ViewBuilder private func actions(_ m: MachineReseau) -> some View {
        let e = m.etat
        TitreSection(texte: "Machine")
        Carte {
            if !m.enLigne {
                bouton("power", "Réveiller", actif: e?.reveilPossible ?? true) {
                    Task { await modele.agir(.reveiller, sur: id) }
                }
            } else {
                bouton(e?.pause == true ? "play" : "pause", e?.pause == true ? "Reprendre" : "Mettre en pause") {
                    Task { await modele.agir(e?.pause == true ? .reprendre : .pause, sur: id) }
                }
                Filet(retrait: 60)
                bouton("arrow.clockwise", "Redémarrer…", actif: e?.peutRedemarrer ?? false) {
                    confirmation = .redemarrer(m.nom)
                }
                Filet(retrait: 60)
                bouton("power", "Éteindre…", couleur: Q.deconnexion, actif: e?.peutArreter ?? false) {
                    confirmation = .eteindre(m.nom)
                }
            }
        }
        Note(texte: "En pause, la machine n’ouvre plus de nouvelle session ; celles en cours continuent.")
    }

    private func retrait(_ m: MembreCharte) -> some View {
        Carte {
            Button { confirmation = .retirer(m.nom) } label: {
                RangeeReglage(symbole: "person.crop.circle.badge.minus", titre: "Retirer du réseau…",
                              couleur: Q.deconnexion, chevron: false)
            }
            .buttonStyle(.plain).disabled(gele)
        }
        .padding(.top, 32)
    }

    private func bouton(_ symbole: String, _ titre: String, couleur: Color = Q.texte, actif: Bool = true,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RangeeReglage(symbole: symbole, titre: titre, couleur: actif ? couleur : Q.tertiaire, chevron: false)
        }
        .buttonStyle(.plain).disabled(gele || !actif)
    }

    private func executer(_ c: ConfirmationMembre) async {
        switch c {
        case .redemarrer: await modele.agir(.redemarrer, sur: id)
        case .eteindre: await modele.agir(.arreter, sur: id)
        case .retirer:
            await modele.editer("Retrait…") { ch, moi, le in
                try EditionCharte.retirerMembre(ch, auteur: moi, membre: id, le: le)
            }
        }
    }

    private var parti: some View {
        VStack(spacing: 0) {
            Carte { RangeeReglage(titre: "Ce membre n’est plus dans le réseau", couleur: Q.tertiaire, chevron: false) }
                .padding(.top, 8)
        }
    }
}

private enum ConfirmationMembre: Equatable {
    case redemarrer(String), eteindre(String), retirer(String)

    var titre: String {
        switch self {
        case .redemarrer(let n): return "Redémarrer \(n) ?"
        case .eteindre(let n): return "Éteindre \(n) ?"
        case .retirer(let n): return "Retirer \(n) du réseau ?"
        }
    }

    var bouton: String {
        switch self {
        case .redemarrer: return "Redémarrer"
        case .eteindre: return "Éteindre"
        case .retirer: return "Retirer"
        }
    }

    var message: String {
        switch self {
        case .redemarrer: return "Le service Lanterne de la machine redémarre ; ses sessions reprennent ensuite."
        case .eteindre: return "Les sessions de cette machine s’arrêteront. Réveil possible si elle le permet."
        case .retirer:
            return "Il perd l’accès sur toutes les machines du réseau. Il faudra un nouveau code pour revenir."
        }
    }
}

/// Droits du membre (voir, piloter, lancer, Remote Control) : un interrupteur par droit ; un chef les a tous.
private struct DroitsMembreVue: View {
    let modele: ModeleReseau
    let membre: MembreCharte
    let chef: Bool
    let gele: Bool

    var body: some View {
        TitreSection(texte: "Droits")
        Carte {
            interrupteur("Voir les sessions", \.voir)
            Filet()
            interrupteur("Piloter (écrire, interrompre)", \.piloter)
            Filet()
            interrupteur("Lancer des sessions", \.lancer)
            Filet()
            interrupteur("Remote Control", \.remoteControl)
        }
        if chef { Note(texte: "Un chef a tous les droits, quels que soient ces réglages.") }
    }

    private func interrupteur(_ titre: String, _ droit: WritableKeyPath<DroitsMembre, Bool>) -> some View {
        Toggle(isOn: Binding(get: { chef || membre.droits[keyPath: droit] }, set: { changer(droit, $0) })) {
            Text(titre).font(Q.rangee).foregroundStyle(Q.texte)
        }
        .tint(Q.coche).padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur)
        .disabled(gele || chef)
    }

    private func changer(_ droit: WritableKeyPath<DroitsMembre, Bool>, _ valeur: Bool) {
        var droits = membre.droits
        droits[keyPath: droit] = valeur
        let id = membre.id
        let fixes = droits
        Task {
            await modele.editer("Signature…") { c, moi, le in
                try EditionCharte.changerMembre(c, auteur: moi, membre: id, droits: fixes, compte: nil, nom: nil,
                                                le: le)
            }
        }
    }
}

/// Compte Claude par défaut de la machine (sessions ouvertes sans compte) : choisi parmi ceux qu'elle annonce.
private struct CompteMembreVue: View {
    let modele: ModeleReseau
    let membre: MembreCharte
    let machine: MachineReseau?
    let gele: Bool

    var body: some View {
        let comptes = machine?.etat?.comptes ?? []
        TitreSection(texte: "Compte Claude")
        Carte {
            HStack {
                Text("Compte par défaut").font(Q.rangee).foregroundStyle(Q.texte)
                Spacer()
                Picker("Compte", selection: Binding(get: { membre.compte ?? "" }, set: { choisir($0) })) {
                    Text("Celui de la machine").tag("")
                    ForEach(comptes, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu).tint(Q.secondaire)
            }
            .padding(.leading, Q.marge).padding(.trailing, 4).frame(height: Q.rangeeHauteur)
            .disabled(gele || comptes.isEmpty)
        }
    }

    private func choisir(_ valeur: String) {
        let id = membre.id
        let compte: String? = valeur.isEmpty ? nil : valeur
        Task {
            await modele.editer("Signature…") { c, moi, le in
                try EditionCharte.changerMembre(c, auteur: moi, membre: id, droits: nil, compte: .some(compte),
                                                nom: nil, le: le)
            }
        }
    }
}

/// Ressources d'une machine en ligne : processeur, mémoire, cartes graphiques, fonctions.
private struct RessourcesMachine: View {
    let etat: EtatMachineReseau

    var body: some View {
        TitreSection(texte: "Ressources")
        Carte {
            if let cpu = etat.cpu { jauge("cpu", "Processeur", "\(Int(cpu.rounded())) %", cpu / 100) }
            if let u = etat.memoireUtilisee, let t = etat.memoireTotale, t > 0 {
                Filet(retrait: 60)
                jauge("memorychip", "Mémoire", "\(Self.go(u)) / \(Self.go(t)) Go", u / t)
            }
            ForEach(Array(etat.gpu.enumerated()), id: \.offset) { _, g in
                Filet(retrait: 60)
                jauge("square.stack.3d.up", g.nom, g.utilisation.map { "\(Int($0.rounded())) %" } ?? "—",
                      (g.utilisation ?? 0) / 100)
            }
            Filet(retrait: 60)
            RangeeReglage(symbole: "waveform", titre: "Voix", valeur: Self.fonction(etat.voix), chevron: false)
            Filet(retrait: 60)
            RangeeReglage(symbole: "mic", titre: "Dictée", valeur: Self.fonction(etat.dictee), chevron: false)
        }
    }

    private func jauge(_ symbole: String, _ titre: String, _ valeur: String, _ part: Double) -> some View {
        VStack(spacing: 6) {
            RangeeReglage(symbole: symbole, titre: titre, valeur: valeur, chevron: false)
            Jauge(part: part).padding(.leading, 60).padding(.trailing, Q.marge).padding(.bottom, 10)
        }
    }

    private static func go(_ octets: Double) -> String {
        String(format: "%.1f", octets / 1_073_741_824).replacingOccurrences(of: ".", with: ",")
    }

    private static func fonction(_ etat: String) -> String {
        switch etat {
        case "lancee": return "Lancée"
        case "arretee": return "Arrêtée"
        default: return "Absente"
        }
    }
}
#endif
