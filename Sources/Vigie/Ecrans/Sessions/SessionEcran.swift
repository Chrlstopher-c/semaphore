// Une session : son état (contexte, autonomie), son fil en direct, et de quoi lui parler ou la piloter.
// Cet écran sert à suivre ce que fait Claude ; l'élément dominant est le fil.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct SessionEcran: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.palette) private var p
    let id: String
    @State private var erreur: String?

    var body: some View {
        Group {
            if let s = modele.session(id) { contenu(s) } else {
                EtatVide(symbole: "questionmark", titre: "Session introuvable", texte: "Elle a peut-être été retirée du relais.")
            }
        }
        .background(p.fond.ignoresSafeArea())
        .toolbarBackground(p.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task(id: id) { await modele.suivreFil(id) }
        .onAppear { Aiguillage.partage.sessionVisible = id }
        .onDisappear { Aiguillage.partage.sessionVisible = nil }
    }

    private func contenu(_ s: Session) -> some View {
        VStack(spacing: 0) {
            EnTeteSession(session: s, erreur: $erreur)
            if let erreur { BandeauErreur(texte: erreur) { self.erreur = nil }.padding(.horizontal, Espace.marge) }
            FilVue(evenements: modele.fils[id] ?? [], dossier: s.cwd)
            ComposeurSession(session: s, erreur: $erreur)
        }
        .navigationTitle(s.titre)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EnTeteSession: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.palette) private var p
    let session: Session
    @Binding var erreur: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Espace.m) {
            HStack(spacing: Espace.s) {
                Surtitre(texte: "\(session.machine) · \(session.projet.nom)")
                Spacer()
                Pastille(texte: session.statut.libelle, ton: pastille(session.statut))
            }
            contexte
            actions
        }
        .padding(.horizontal, Espace.marge).padding(.vertical, Espace.m)
        .background(p.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(p.filet).frame(height: 1) }
    }

    /// Rouge au seuil de compaction dure (35 % d'une fenêtre de 1 M) : au-delà, chaque tour coûte cher.
    private var contexte: some View {
        VStack(alignment: .leading, spacing: Espace.xs) {
            HStack {
                Text("contexte").font(Voix.etiquette).foregroundStyle(p.discret)
                Spacer()
                Text("\(Format.tokens(session.contexte.tokens)) / \(Format.tokens(session.contexte.max)) · \(session.etapes) ét. · "
                     + "\(session.compactions) comp.").font(Voix.chiffre).foregroundStyle(p.discret).monospacedDigit()
            }
            Jauge(valeur: session.contexte.ratio, alerte: 0.35)
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: Espace.s) {
            if session.ouverte {
                bouton("Interrompre", "stop.fill") { await modele.agir(.interrompre, sur: session.id) }
                bouton("Compacter", "arrow.down.right.and.arrow.up.left") { await modele.agir(.compacter, sur: session.id) }
            } else {
                bouton("Reprendre", "play.fill") { await modele.agir(.reprendre, sur: session.id) }
            }
            Spacer()
            if session.pilotee {
                Toggle(isOn: Binding(get: { session.autonomie }, set: { v in
                    Task { erreur = await modele.basculerAutonomie(v, de: session.id) }
                })) { Text("Auto").font(Voix.petit.weight(.bold)).foregroundStyle(p.encreDouce) }
                    .fixedSize().tint(p.accent)
            }
        }
    }

    private func bouton(_ titre: String, _ symbole: String, _ f: @escaping () async -> String?) -> some View {
        Button { Task { erreur = await f() } } label: { Label(titre, systemImage: symbole).labelStyle(.titleAndIcon) }
            .buttonStyle(StyleBoutonDiscret())
            .sensoryFeedback(.impact(weight: .light), trigger: erreur)
    }

    private func pastille(_ s: StatutSession) -> Pastille.Ton {
        switch s {
        case .question: return .alerte
        case .erreur: return .danger
        case .terminee: return .succes
        case .fermee: return .neutre
        default: return .accent
        }
    }
}

struct ComposeurSession: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.palette) private var p
    let session: Session
    @Binding var erreur: String?
    @State private var texte = ""
    @State private var envoi = false
    @FocusState private var focus: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: Espace.s) {
            TextField(aide, text: $texte, axis: .vertical)
                .lineLimit(1...6).font(.system(size: 16)).focused($focus)
                .padding(.horizontal, Espace.m).padding(.vertical, Espace.m)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(p.surface2))
            Button { Task { await envoyer() } } label: {
                Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Circle().fill(p.accent))
            }
            .disabled(texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || envoi)
            .opacity(texte.isEmpty ? 0.45 : 1)
            .accessibilityLabel("Envoyer")
        }
        .padding(.horizontal, Espace.marge).padding(.vertical, Espace.s)
        .background(p.surface)
        .overlay(alignment: .top) { Rectangle().fill(p.filet).frame(height: 1) }
        .sensoryFeedback(.impact(weight: .medium), trigger: envoi)
    }

    private var aide: String {
        if !session.ouverte { return "Écrire la reprend…" }
        return session.statut.enActivite ? "Lu à la fin de son tour…" : "Écrire à la session…"
    }

    private func envoyer() async {
        let t = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        envoi = true
        defer { envoi = false }
        if let e = await modele.envoyer(t, a: session.id) { erreur = e } else { texte = "" }
    }
}
#endif
