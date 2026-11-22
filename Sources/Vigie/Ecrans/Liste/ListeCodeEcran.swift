// La liste « Code » (étalon 014) : en-tête tiroir / titre / filtre, appareils du parc, sessions au pas de 75 pt,
// loupe et capsule « Nouvelle session » posées en bas. Appui long : épingler, renommer, archiver.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ListeCodeEcran: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.ouvrirTiroir) private var ouvrirTiroir
    let nouvelleSession: () -> Void
    @State private var archivees = false
    @State private var recherche = ""
    @State private var chercher = false
    @State private var bandeau: String?
    @State private var aRenommer: Session?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !archivees {
                    TitreListe(texte: "Appareils")
                    BandeAppareils()
                }
                TitreListe(texte: archivees ? "Archivées" : "Sessions")
                sessions
            }
            .padding(.bottom, 120)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Q.fondListe.ignoresSafeArea())
        .overlay(alignment: .bottom) { barreBas }
        .overlay(alignment: .top) { etatLien }
        .toolbar { entete }
        .toolbarBackground(Q.fondListe, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .searchable(text: $recherche, isPresented: $chercher, placement: .navigationBarDrawer, prompt: "Rechercher")
        .renommage(session: $aRenommer, bandeau: $bandeau)
    }

    private var lignes: [LigneSession] {
        let toutes = ListeSessions.lignes(
            modele.sessions, machines: modele.machines,
            maintenant: .now, archivees: archivees)
        let cle = recherche.trimmingCharacters(in: .whitespaces)
        return cle.isEmpty ? toutes : toutes.filter { $0.titre.localizedCaseInsensitiveContains(cle) }
    }

    @ViewBuilder private var sessions: some View {
        let liste = lignes
        if liste.isEmpty {
            EtatVideListe(
                archivees: archivees, recherche: !recherche.isEmpty,
                lien: modele.lien, nouvelle: nouvelleSession)
        }
        ForEach(liste) { ligne in
            NavigationLink(value: ligne.id) { LigneSessionVue(ligne: ligne) }
                .buttonStyle(StyleAppui())
                .contextMenu { menu(ligne.id) }
        }
    }

    @ViewBuilder private func menu(_ id: String) -> some View {
        if let s = modele.session(id) {
            Button(s.epinglee == true ? "Désépingler" : "Épingler",
                   systemImage: s.epinglee == true ? "pin.slash" : "pin") {
                agir(s.epinglee == true ? .desepingler : .epingler, id)
            }
            Button("Renommer", systemImage: "pencil") { aRenommer = s }
            Button(s.nonLue == true ? "Marquer comme lue" : "Marquer comme non lue", systemImage: "circle.badge") {
                agir(s.nonLue == true ? .marquerLue : .marquerNonLue, id)
            }
            Divider()
            Button(s.archivee == true ? "Désarchiver" : "Archiver", systemImage: "archivebox") {
                agir(s.archivee == true ? .desarchiver : .archiver, id)
            }
        }
    }

    private func agir(_ action: ActionSession, _ id: String) {
        Task { if let e = await modele.agir(action, sur: id) { montrer(e) } }
    }

    private func montrer(_ texte: String) {
        withAnimation(.smooth) { bandeau = texte }
        Task { try? await Task.sleep(for: .seconds(3)); withAnimation(.smooth) { bandeau = nil } }
    }

    @ToolbarContentBuilder private var entete: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { ouvrirTiroir() } label: { GlypheTiroir() }.accessibilityLabel("Menu")
        }
        ToolbarItem(placement: .principal) {
            Text(archivees ? "Archivées" : "Code").font(Q.titreNav).foregroundStyle(Q.texte)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Toggle("Afficher les archivées", systemImage: "archivebox", isOn: $archivees.animation(.smooth))
            } label: {
                Image(systemName: archivees ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                    .font(.system(size: 20, weight: .light)).foregroundStyle(Q.texte).frame(width: 44, height: 44)
            }
        }
    }

    private var barreBas: some View {
        HStack {
            BoutonRond(symbole: "magnifyingglass", diametre: 42, fond: Q.carte) { chercher = true }
                .accessibilityLabel("Rechercher")
            Spacer()
            CapsuleBlanche(titre: "Nouvelle session", action: nouvelleSession)
        }
        .padding(.horizontal, 22).padding(.bottom, 8)
    }

    @ViewBuilder private var etatLien: some View {
        if let texte = bandeau ?? texteLien { Bandeau(texte: texte).padding(.top, 4) }
    }

    private var texteLien: String? {
        if case .coupe = modele.lien { return "Hors ligne · nouvel essai en cours" }
        return nil
    }
}

struct TitreListe: View {
    let texte: String

    var body: some View {
        Text(texte)
            .font(Q.detail)
            .foregroundStyle(Q.meta)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }
}

/// Aucune session : on dit pourquoi (pas encore de session, rien d'archivé, recherche vide, relais injoignable).
private struct EtatVideListe: View {
    let archivees: Bool
    let recherche: Bool
    let lien: Lien
    let nouvelle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbole).font(.system(size: 30, weight: .light)).foregroundStyle(Q.tertiaire)
            Text(titre).font(.system(size: 17, weight: .semibold)).foregroundStyle(Q.texte)
            Text(detail).font(Q.detail).foregroundStyle(Q.tertiaire).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 40).padding(.top, 72)
    }

    private var symbole: String {
        if case .coupe = lien { return "wifi.exclamationmark" }
        return recherche ? "magnifyingglass" : (archivees ? "archivebox" : "chevron.left.forwardslash.chevron.right")
    }

    private var titre: String {
        if case .coupe = lien { return "Nœud injoignable" }
        if lien == .attente { return "Connexion au nœud…" }
        return recherche ? "Aucun résultat" : (archivees ? "Rien d’archivé" : "Aucune session")
    }

    private var detail: String {
        if case .coupe(let raison) = lien { return raison }
        if lien == .attente { return "Les sessions du parc arrivent." }
        if recherche { return "Aucun titre ne contient ce texte." }
        return archivees ? "Les sessions rangées apparaîtront ici." : "Lance une session sur une machine du parc."
    }
}
#endif
