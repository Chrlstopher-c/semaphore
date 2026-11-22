// Le composeur (étalon 001/002). Au repos : capsule « Réponds à Claude » avec « + » à gauche et arrêt à droite pendant
// le travail. En saisie : carte arrondie, champ en haut, rangée « + », pilule du modèle, envoyer / arrêter en bas.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct Composeur: View {
    @Environment(ModeleRelais.self) private var modele
    let session: Session
    let ouvrirModele: () -> Void
    let ouvrirUsage: () -> Void
    let ouvrirTaches: () -> Void
    let erreur: (String) -> Void
    @State private var texte = ""
    @State private var envoi = 0
    @FocusState private var focus: Bool

    var body: some View {
        Group {
            if !session.pilotable { lectureSeule } else if focus || !texte.isEmpty { etendu } else { repos }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
        .background(Q.entete.ignoresSafeArea(edges: .bottom))
        .animation(.smooth(duration: 0.3), value: focus)
        .sensoryFeedback(.impact(weight: .medium), trigger: envoi)
    }

    private var repos: some View {
        HStack(spacing: 0) {
            MenuPlus(session: session, ouvrirUsage: ouvrirUsage, ouvrirTaches: ouvrirTaches, erreur: erreur)
            Text(invite).font(Q.rangee).foregroundStyle(Q.tertiaire).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
                .contentShape(.rect).onTapGesture { focus = true }
            if session.statut.enActivite { boutonArret }
        }
        .padding(.horizontal, 4).frame(height: 52)
        .background(Q.carte, in: .capsule)
    }

    private var etendu: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(invite, text: $texte, axis: .vertical).font(Q.rangee).foregroundStyle(Q.texte)
                .lineLimit(1...8).focused($focus).padding(.horizontal, 16).padding(.top, 14)
            HStack(spacing: 4) {
                MenuPlus(session: session, ouvrirUsage: ouvrirUsage, ouvrirTaches: ouvrirTaches, erreur: erreur)
                PiluleModele(session: session, action: ouvrirModele)
                Spacer(minLength: 0)
                if !texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    BoutonRond(symbole: "arrow.up", fond: Q.texte, encre: Q.carte, poids: .semibold) { envoyer() }
                        .accessibilityLabel("Envoyer")
                } else if session.statut.enActivite {
                    boutonArret
                }
            }
            .padding(.horizontal, 4).padding(.bottom, 4)
        }
        .background(Q.carte, in: .rect(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Q.pilule))
    }

    private var boutonArret: some View {
        Button { Task { if let e = await modele.interrompre(session.id) { erreur(e) } } } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Q.texte).frame(width: 12, height: 12)
                .frame(width: 36, height: 36).background(Q.rond, in: .circle).frame(width: 44, height: 44)
        }
        .buttonStyle(StyleAppui())
        .accessibilityLabel("Interrompre")
    }

    /// Session fermée ou suivie en lecture seule : on le dit, et on propose de la reprendre quand c'est possible.
    private var lectureSeule: some View {
        HStack {
            Text(session.statut == .fermee ? "Session fermée" : "Lecture seule")
                .font(Q.rangee)
                .foregroundStyle(Q.tertiaire)
            Spacer()
            if session.statut == .fermee && session.moteur != "claude_ai" {
                Button("Reprendre") {
                    Task { if let e = await modele.agir(.reprendre, sur: session.id) { erreur(e) } }
                }
                .font(.system(size: 17, weight: .medium)).foregroundStyle(Q.lien)
            }
        }
        .padding(.horizontal, 20).frame(height: 52)
        .background(Q.carte, in: .capsule)
    }

    private var invite: String {
        session.statut.enActivite ? "Ajoute un message, il attendra la fin du tour" : "Réponds à Claude"
    }

    private func envoyer() {
        let message = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        texte = ""
        envoi += 1
        Task {
            if let e = await modele.envoyer(message, a: session.id) {
                texte = message
                erreur(e)
            }
        }
    }
}

/// Pilule « Opus 5.5 Moyen » (étalon 002) : ouvre la feuille du modèle.
private struct PiluleModele: View {
    let session: Session
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(CatalogueModeles.nom(session)).foregroundStyle(Q.texte)
                if let effort = CatalogueModeles.libelleEffort(session.effortSession) {
                    Text(effort).foregroundStyle(Q.tertiaire)
                }
            }
            .font(Q.detail).lineLimit(1)
            .padding(.horizontal, 14).frame(height: 36)
            .background(Q.rond, in: .capsule)
        }
        .buttonStyle(StyleAppui())
    }
}

/// Le « + » : mode de permission, compaction, usage, tâches de fond.
private struct MenuPlus: View {
    @Environment(ModeleRelais.self) private var modele
    let session: Session
    let ouvrirUsage: () -> Void
    let ouvrirTaches: () -> Void
    let erreur: (String) -> Void

    var body: some View {
        Menu {
            Picker("Permissions", selection: mode) {
                ForEach(CatalogueModeles.modesPermission, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.menu)
            Button("Compacter le contexte", systemImage: "arrow.down.right.and.arrow.up.left") {
                Task { if let e = await modele.agir(.compacter, sur: session.id) { erreur(e) } }
            }
            Button("Usage", systemImage: "gauge.with.dots.needle.33percent", action: ouvrirUsage)
            Button("Tâches de fond", systemImage: "diamond", action: ouvrirTaches)
        } label: {
            Image(systemName: "plus").font(.system(size: 17)).foregroundStyle(Q.texte)
                .frame(width: 36, height: 36).background(Q.rond, in: .circle).frame(width: 44, height: 44)
        }
        .accessibilityLabel("Options")
    }

    private var mode: Binding<String> {
        Binding(get: { session.mode ?? ModeSession.bypassPermissions.rawValue }, set: { nouveau in
            Task { if let e = await modele.changerMode(nouveau, de: session.id) { erreur(e) } }
        })
    }
}
#endif
