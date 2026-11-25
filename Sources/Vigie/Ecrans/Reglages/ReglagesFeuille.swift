// Les réglages (étalon 017/019) : carte du nœud relié, « Liaison » (réseau, connexion, synchro), « Compte » (usage,
// notifications), « Claude Code » (défauts des nouvelles sessions), veille, puis « Se déconnecter » rosé dans sa
// carte. Ce qui n'a pas d'objet chez nous est absent.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ReglagesFeuille: View {
    @Environment(Cablage.self) private var cablage
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.dismiss) private var fermer
    @State private var confirmer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    carteNoeud.padding(.top, 8)
                    TitreSection(texte: "Liaison")
                    Carte {
                        lien("point.3.connected.trianglepath.dotted", "Réseau") { ReseauReglages() }
                        Filet(retrait: 60)
                        lien("antenna.radiowaves.left.and.right", "Connexion") { ConnexionReglages() }
                        Filet(retrait: 60)
                        lien("arrow.triangle.2.circlepath", "Synchronisation") { SynchroReglages() }
                    }
                    TitreSection(texte: "Compte")
                    Carte {
                        lien("gauge.with.dots.needle.33percent", "Usage") { UsageContenu(sessionId: nil) }
                        Filet(retrait: 60)
                        lien("bell", "Notifications") { NotificationsReglages() }
                    }
                    TitreSection(texte: "Appli")
                    Carte { lien("chevron.left.forwardslash.chevron.right", "Claude Code") { ClaudeCodeReglages() } }
                    Carte { deconnexion }.padding(.top, 32)
                }
                .padding(.bottom, 32)
            }
            .barreFeuille("Réglages")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BoutonEntete(symbole: "xmark") { fermer() } }
            }
        }
        .presentationBackground(Q.fondFil)
        .confirmationDialog("Se déconnecter du nœud ?", isPresented: $confirmer, titleVisibility: .visible) {
            Button("Se déconnecter", role: .destructive) { fermer(); cablage.deconnecter() }
        } message: { Text("La clé de cet iPhone sera oubliée ; il faudra un nouveau code d’appairage.") }
    }

    private var carteNoeud: some View {
        Carte {
            HStack(spacing: 14) {
                Text("Q").font(.system(size: 17, weight: .medium, design: .serif)).foregroundStyle(Q.texte)
                    .frame(width: 44, height: 44).background(Color.black, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cablage.nomNoeudActif ?? "Nœud Lanterne").font(Q.rangee).foregroundStyle(Q.texte)
                    Text("\(hote) · \(etatLien)").font(Q.detail)
                        .foregroundStyle(Q.secondaire).lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, Q.marge).frame(height: 68)
        }
    }

    /// Hôte affiché : celui de l'aiguilleur quand on passe par lui, sinon celui du nœud.
    private var hote: String {
        if let a = cablage.etatAiguilleur, let h = URL(string: a.adresse)?.host() { return "par \(h)" }
        return cablage.adresse.host() ?? cablage.adresse.absoluteString
    }

    private var etatLien: String {
        switch modele.lien {
        case .connecte: return "\(modele.machines.filter(\.enLigne).count) machine(s) en ligne"
        case .attente: return "connexion…"
        case .coupe: return "hors ligne"
        case .nonConnecte: return "clé refusée"
        }
    }

    private var deconnexion: some View {
        Button { confirmer = true } label: {
            HStack(spacing: 16) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 19, weight: .light))
                    .frame(width: 28)
                Text("Se déconnecter").font(Q.rangee)
                Spacer()
            }
            .foregroundStyle(Q.deconnexion)
            .padding(.horizontal, Q.marge)
            .frame(height: Q.rangeeHauteur)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func lien<D: View>(
        _ symbole: String, _ titre: String,
        @ViewBuilder destination: @escaping () -> D
    ) -> some View {
        NavigationLink { destination() } label: { RangeeReglage(symbole: symbole, titre: titre) }.buttonStyle(.plain)
    }
}

/// Défauts des nouvelles sessions : modèle, effort, permissions.
private struct ClaudeCodeReglages: View {
    @State private var modeleId = PreferencesQuart.modeleParDefaut
    @State private var effort = PreferencesQuart.effortParDefaut ?? ""
    @State private var mode = PreferencesQuart.modeParDefaut ?? ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TitreSection(texte: "Nouvelles sessions")
                Carte {
                    selecteur("Modèle", $modeleId,
                        (CatalogueModeles.principaux + CatalogueModeles.autres).map { ($0.id, $0.nom) })
                    Filet()
                    selecteur("Effort", $effort, [("", "Par défaut")] + EffortSession.allCases.map {
                        ($0.rawValue, CatalogueModeles.libelleEffort($0) ?? $0.rawValue)
                    })
                    Filet()
                    selecteur("Permissions", $mode, [("", "Par défaut")] + CatalogueModeles.modesPermission)
                }
            }
        }
        .barreFeuille("Claude Code")
        .onChange(of: modeleId) { _, v in PreferencesQuart.modeleParDefaut = v }
        .onChange(of: effort) { _, v in PreferencesQuart.effortParDefaut = v.isEmpty ? nil : v }
        .onChange(of: mode) { _, v in PreferencesQuart.modeParDefaut = v.isEmpty ? nil : v }
    }

    private func selecteur(_ titre: String, _ valeur: Binding<String>, _ choix: [(String, String)]) -> some View {
        HStack {
            Text(titre).font(Q.rangee).foregroundStyle(Q.texte)
            Spacer()
            Picker(titre, selection: valeur) { ForEach(choix, id: \.0) { Text($0.1).tag($0.0) } }
                .pickerStyle(.menu).tint(Q.secondaire)
        }
        .padding(.leading, Q.marge).padding(.trailing, 4).frame(height: Q.rangeeHauteur)
    }
}

/// Notifications : la veille de Vigie (maintien en vie), gardée telle quelle.
private struct NotificationsReglages: View {
    @State private var maintien = PreferencesAlerte.maintienEnVie
    @State private var parNtfy = PreferencesAlerte.notificationsParNtfy

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                TitreSection(texte: "Veille")
                Carte {
                    Toggle(isOn: $maintien) { Text("Veille en arrière-plan").font(Q.rangee).foregroundStyle(Q.texte) }
                        .tint(Q.coche).padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur)
                    Toggle(isOn: $parNtfy) { Text("Notifications push (ntfy)").font(Q.rangee).foregroundStyle(Q.texte) }
                        .tint(Q.coche).padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur)
                }
                Text("Les questions, fins de tour et erreurs arrivent par l'app ntfy, instantanément. Coupé : l'app les sonne elle-même.")
                    .font(Q.detail).foregroundStyle(Q.secondaire).padding(.horizontal, 32)
                Text("Garde Quart éveillé pour sonner les questions, les fins de tour et les erreurs, écran éteint.")
                    .font(Q.detail).foregroundStyle(Q.secondaire).padding(.horizontal, 32)
            }
        }
        .barreFeuille("Notifications")
        .onChange(of: parNtfy) { _, actif in PreferencesAlerte.notificationsParNtfy = actif }
        .onChange(of: maintien) { _, actif in
            PreferencesAlerte.maintienEnVie = actif
            if actif { MaintienVie.partage.demarrer() } else { MaintienVie.partage.arreter() }
        }
    }
}
#endif
