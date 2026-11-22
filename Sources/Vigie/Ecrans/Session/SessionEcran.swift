// L'écran d'une session (étalon 001) : en-tête à trois traits / titre sur deux lignes / anneau d'usage / « ··· »,
// fil, demande en attente, composeur. Les feuilles (modèle, usage, tâches, actions) partent d'ici.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

enum FeuilleSession: Identifiable {
    case modele, usage, taches, actions(GroupeActions)

    var id: String {
        switch self {
        case .modele: return "modele"
        case .usage: return "usage"
        case .taches: return "taches"
        case .actions(let g): return "actions-\(g.id)"
        }
    }
}

struct SessionEcran: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.ouvrirTiroir) private var ouvrirTiroir
    let id: String
    @State private var feuille: FeuilleSession?
    @State private var bandeau: String?
    @State private var aRenommer: Session?

    var body: some View {
        Group {
            if let s = modele.session(id) { contenu(s) } else { introuvable }
        }
        .background(Q.fondFil.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Q.entete, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task(id: id) { await modele.suivreFil(id) }
        .task(id: id) { if modele.session(id)?.nonLue == true { _ = await modele.agir(.marquerLue, sur: id) } }
        .overlay(alignment: .top) { if let bandeau { Bandeau(texte: bandeau).padding(.top, 4) } }
        .sheet(item: $feuille) { f in feuilleVue(f) }
        .renommage(session: $aRenommer, bandeau: $bandeau)
    }

    private func contenu(_ s: Session) -> some View {
        FilQuart(session: s, ouvrirActions: { feuille = .actions($0) }, ouvrirTaches: { feuille = .taches })
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if let d = s.dialogue { DemandeVue(session: s, dialogue: d, erreur: montrer) }
                    Composeur(session: s, ouvrirModele: { feuille = .modele }, ouvrirUsage: { feuille = .usage },
                              ouvrirTaches: { feuille = .taches }, erreur: montrer)
                }
            }
            .toolbar { entete(s) }
    }

    private var introuvable: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.bubble")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Q.tertiaire)
            Text("Session introuvable").font(.system(size: 17, weight: .semibold)).foregroundStyle(Q.texte)
            Text("Elle a peut-être été supprimée, ou le nœud ne la connaît plus.").font(Q.detail)
                .foregroundStyle(Q.tertiaire).multilineTextAlignment(.center)
        }
        .padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder private func entete(_ s: Session) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { ouvrirTiroir() } label: { GlypheTiroir() }.accessibilityLabel("Menu")
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(TitreSession.affiche(s, premierMessage: modele.premiersMessages[s.id]))
                    .font(Q.titreNav).foregroundStyle(Q.titre).lineLimit(1)
                Text("\(s.machine) · \(s.projet.nom)").font(Q.sousTitreNav).foregroundStyle(Q.secondaire).lineLimit(1)
            }
            .frame(maxWidth: 210)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 4) {
                Button { feuille = .usage } label: { AnneauUsage(part: partUsage(s)).frame(width: 44, height: 44) }
                    .accessibilityLabel("Usage")
                MenuSession(session: s, taches: { feuille = .taches }, renommer: { aRenommer = s }, erreur: montrer)
            }
        }
    }

    /// L'anneau montre l'usage hebdomadaire du compte (comme l'étalon), sinon le remplissage du contexte.
    private func partUsage(_ s: Session) -> Double {
        let compte = modele.machine(s.machine)?.etatComptes.first { $0.id == s.compte } ?? modele.machine(s.machine)?
            .etatComptes.first { $0.defaut }
        if let semaine = compte?.semaine { return semaine.pourcent / 100 }
        return s.contexte.ratio
    }

    @ViewBuilder private func feuilleVue(_ f: FeuilleSession) -> some View {
        switch f {
        case .modele: ModeleFeuille(sessionId: id)
        case .usage: UsageFeuille(sessionId: id)
        case .taches: TachesFeuille(sessionId: id)
        case .actions(let g): ActionsFeuille(groupe: g)
        }
    }

    private func montrer(_ texte: String) {
        withAnimation(.smooth) { bandeau = texte }
        Task { try? await Task.sleep(for: .seconds(3)); withAnimation(.smooth) { bandeau = nil } }
    }
}

/// Le menu « ··· » (étalon 011) : tâches de fond ; partager, renommer, archiver ; épingler.
private struct MenuSession: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.dismiss) private var fermer
    let session: Session
    let taches: () -> Void
    let renommer: () -> Void
    let erreur: (String) -> Void

    var body: some View {
        Menu {
            Section { Button("Tâches de fond", systemImage: "diamond", action: taches) }
            Section {
                ShareLink(item: "\(session.titre) — \(session.machine) · \(session.cwd)") {
                    Label("Partager", systemImage: "square.and.arrow.up")
                }
                Button("Renommer", systemImage: "pencil", action: renommer)
                Button(session.epinglee == true ? "Désépingler" : "Épingler", systemImage: "pin") {
                    agir(session.epinglee == true ? .desepingler : .epingler)
                }
                Button("Archiver", systemImage: "archivebox") { agir(.archiver); fermer() }
            }
            Section { pilotage }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 11, weight: .bold)).foregroundStyle(Q.secondaire)
                .frame(width: 22, height: 22).overlay(Circle().strokeBorder(Q.secondaire, lineWidth: 1.3))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Plus")
    }

    @ViewBuilder private var pilotage: some View {
        if session.statut == .fermee {
            Button("Reprendre", systemImage: "play") { agir(.reprendre) }
        } else {
            Button("Compacter le contexte", systemImage: "arrow.down.right.and.arrow.up.left") { agir(.compacter) }
            Button("Fermer la session", systemImage: "xmark.circle", role: .destructive) { agir(.fermer) }
        }
    }

    private func agir(_ action: ActionSession) {
        Task { if let e = await modele.agir(action, sur: session.id) { erreur(e) } }
    }
}
#endif
