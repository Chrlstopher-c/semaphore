// Nouvelle session, dans la grammaire de l'étalon : un écran de conversation vide poussé dans la pile (même en-tête,
// même fond, même composeur), un accueil en serif au tiers haut, et juste au-dessus du champ les pastilles
// d'environnement (machine, dossier) qui déroulent leur menu. La session ouverte remplace cet écran.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct NouvelleSessionEcran: View {
    /// Valeur de la pile qui désigne cet écran (les autres valeurs sont des identifiants de session).
    static let route = "quart:nouvelle"

    @Environment(ModeleRelais.self) private var modele
    @Environment(\.ouvrirTiroir) private var ouvrirTiroir
    var machineInitiale: String? = nil
    let ouverte: (String) -> Void
    @State private var machine: String?
    @State private var dossier: Projet?
    @State private var recents: [Environnement] = []
    @State private var texte = ""
    @State private var pieces: [PieceSaisie] = []
    @State private var modeleId = PreferencesQuart.modeleParDefaut
    @State private var envoi = false
    @State private var bandeau: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("Que fait-on\u{00a0}?").font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(Q.texte)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
            BandeEnvironnement(machine: $machine, dossier: $dossier, dossiers: dossiers)
        }
        .frame(maxWidth: .infinity)
        .background(Q.fondFil.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { champ }
        .overlay(alignment: .top) { if let bandeau { Bandeau(texte: bandeau).padding(.top, 4) } }
        .toolbar { entete }
        .toolbarBackground(Q.entete, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .task { await preparer() }
    }

    @ToolbarContentBuilder private var entete: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { ouvrirTiroir() } label: { GlypheTiroir() }.accessibilityLabel("Menu")
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text("Nouvelle session").font(Q.titreNav).foregroundStyle(Q.titre)
                Text([machine, dossier?.nom].compactMap { $0 }.joined(separator: " · ")).font(Q.sousTitreNav)
                    .foregroundStyle(Q.secondaire).lineLimit(1)
            }
        }
    }

    private var champ: some View {
        ChampSaisie(texte: $texte, pieces: $pieces, invite: "Que doit faire Claude ?", enEnvoi: envoi,
                    envoyer: { Task { await ouvrir() } }, erreur: montrer) {
            MenuPlus(session: nil, pieces: $pieces, erreur: montrer)
        } pilule: {
            Menu {
                ForEach(CatalogueModeles.principaux + CatalogueModeles.autres, id: \.id) { m in
                    Button { modeleId = m.id } label: {
                        if m.id == modeleId { Label(m.nom, systemImage: "checkmark") } else { Text(m.nom) }
                    }
                }
            } label: {
                Text(CatalogueModeles.nom(id: modeleId)).font(Q.rangee).foregroundStyle(Q.texte)
                    .padding(.horizontal, 14).frame(height: 36).background(Q.rond, in: .capsule)
            }
        }
    }

    private var dossiers: [Projet] {
        guard let machine, let m = modele.machine(machine) else { return [] }
        var vus = Set(m.projets.map(\.chemin))
        let anciens = recents.filter { $0.machine == machine && vus.insert($0.dossier).inserted }
            .map { Projet(machine: machine, chemin: $0.dossier, nom: ($0.dossier as NSString).lastPathComponent) }
        return anciens + m.projets
    }

    private func preparer() async {
        if machine == nil { machine = machineInitiale ?? modele.machines.first(where: \.enLigne)?.id }
        if case .success(let e) = await modele.environnements() { recents = e }
        if dossier == nil { dossier = dossiers.first }
    }

    private func ouvrir() async {
        let message = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let machine else { montrer("Choisis une machine."); return }
        guard let dossier else { montrer("Choisis un dossier."); return }
        guard !message.isEmpty || !pieces.isEmpty else { return }
        envoi = true
        let premier = message.isEmpty ? "Pièce jointe" : message
        var demande = DemandeOuverture(machine: machine, projet: dossier, message: premier,
                                       titre: nil, objectif: nil, autonomie: true, modele: modeleId,
                                       mode: PreferencesQuart.modeParDefaut, effort: PreferencesQuart.effortParDefaut)
        if !pieces.isEmpty { demande.pieces = pieces.map(\.piece) }
        switch await modele.ouvrir(demande) {
        case .success(let s): ouverte(s.id)
        case .failure(let e): montrer(e.description); envoi = false
        }
    }

    private func montrer(_ texte: String) {
        withAnimation(.smooth) { bandeau = texte }
        Task { try? await Task.sleep(for: .seconds(3)); withAnimation(.smooth) { bandeau = nil } }
    }
}

/// Pastilles d'environnement au-dessus du champ (dessin de « + Add device » : capsule liserée) : machine et dossier.
private struct BandeEnvironnement: View {
    @Environment(ModeleRelais.self) private var modele
    @Binding var machine: String?
    @Binding var dossier: Projet?
    let dossiers: [Projet]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu { machines } label: {
                    pastille(symbole: "desktopcomputer", texte: machine ?? "Machine", actif: machine != nil)
                }
                Menu { listeDossiers } label: {
                    pastille(symbole: "folder", texte: dossier?.nom ?? "Dossier", actif: dossier != nil)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder private var machines: some View {
        ForEach(modele.machines) { m in
            Button { machine = m.id; dossier = nil } label: {
                Label(m.enLigne ? m.id : "\(m.id) · hors ligne", systemImage: m.id == machine ? "checkmark" : "circle")
            }
            .disabled(!m.enLigne)
        }
    }

    @ViewBuilder private var listeDossiers: some View {
        if dossiers.isEmpty { Text(machine == nil ? "Choisis d’abord une machine" : "Aucun dossier connu") }
        ForEach(Array(dossiers.prefix(30).enumerated()), id: \.offset) { _, p in
            Button { dossier = p } label: {
                Label(p.nom, systemImage: p.chemin == dossier?.chemin ? "checkmark" : "folder")
            }
        }
    }

    private func pastille(symbole: String, texte: String, actif: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbole).font(.system(size: 14))
            Text(texte).font(Q.detail).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 11, weight: .medium)).foregroundStyle(Q.tertiaire)
        }
        .foregroundStyle(actif ? Q.texte : Q.tertiaire)
        .padding(.horizontal, 14).frame(height: 36)
        .background(Color(hex: 0x0D0D0D), in: .capsule)
        .overlay(Capsule().strokeBorder(Q.lisere))
    }
}
#endif
