// Nouvelle session : choisir la machine du parc, le dossier (projets de la machine, dossiers récents), le modèle, puis
// écrire la première demande dans le composeur de l'étalon. La session ouverte s'affiche aussitôt.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct NouvelleSessionFeuille: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.dismiss) private var fermer
    var machineInitiale: String? = nil
    let ouverte: (String) -> Void
    @State private var machine: String?
    @State private var dossier: Projet?
    @State private var recents: [Environnement] = []
    @State private var texte = ""
    @State private var modeleId = PreferencesQuart.modeleParDefaut
    @State private var envoi = false
    @State private var erreur: String?
    @FocusState private var focus: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TitreSection(texte: "Machine")
                    carteMachines
                    TitreSection(texte: "Dossier")
                    carteDossiers
                    if let erreur {
                        Text(erreur)
                            .font(Q.detail)
                            .foregroundStyle(Q.retraitTexte)
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { composeur }
            .barreFeuille("Nouvelle session")
            .toolbar { ToolbarItem(placement: .topBarLeading) { BoutonEntete(symbole: "xmark") { fermer() } } }
        }
        .feuilleQuart([.large])
        .task { await preparer() }
    }

    private var enLigne: [Machine] { modele.machines.filter(\.enLigne) }

    private var carteMachines: some View {
        Carte {
            if enLigne.isEmpty { RangeeReglage(titre: "Aucune machine en ligne", couleur: Q.tertiaire, chevron: false) }
            ForEach(Array(enLigne.enumerated()), id: \.offset) { i, m in
                if i > 0 { Filet() }
                choix(titre: m.id, detail: m.description, coche: machine == m.id) { machine = m.id; dossier = nil }
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

    private var carteDossiers: some View {
        Carte {
            if dossiers.isEmpty {
                RangeeReglage(
                    titre: machine == nil ? "Choisis d’abord une machine" : "Aucun dossier connu",
                    couleur: Q.tertiaire,
                    chevron: false)
            }
            ForEach(Array(dossiers.prefix(30).enumerated()), id: \.offset) { i, p in
                if i > 0 { Filet() }
                choix(titre: p.nom, detail: p.chemin, coche: dossier?.chemin == p.chemin) { dossier = p }
            }
        }
    }

    private func choix(titre: String, detail: String, coche: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titre).font(Q.rangee).foregroundStyle(Q.texte).lineLimit(1)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(Q.detail)
                            .foregroundStyle(Q.secondaire)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
                Spacer()
                if coche { Image(systemName: "checkmark").font(.system(size: 20)).foregroundStyle(Q.coche) }
            }
            .padding(.horizontal, Q.marge).frame(minHeight: 56).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var composeur: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Que doit faire Claude ?", text: $texte, axis: .vertical).font(Q.rangee).foregroundStyle(Q.texte)
                .lineLimit(2...8).focused($focus).padding(.horizontal, 16).padding(.top, 14)
            HStack(spacing: 8) {
                Menu {
                    ForEach(CatalogueModeles.principaux + CatalogueModeles.autres, id: \.id) { m in
                        Button(m.nom) { modeleId = m.id }
                    }
                } label: {
                    Text(CatalogueModeles.nom(id: modeleId)).font(Q.detail).foregroundStyle(Q.texte)
                        .padding(.horizontal, 14).frame(height: 36).background(Q.rond, in: .capsule)
                }
                Spacer()
                if envoi { IndicateurTravail().frame(width: 18, height: 18).frame(width: 44, height: 44) } else {
                    BoutonRond(symbole: "arrow.up", fond: pret ? Q.texte : Q.rond, encre: pret ? Q.carte : Q.tertiaire,
                               poids: .semibold) { Task { await ouvrir() } }
                        .disabled(!pret).accessibilityLabel("Lancer")
                }
            }
            .padding(.horizontal, 8).padding(.bottom, 6)
        }
        .background(Q.carte, in: .rect(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Q.pilule))
        .padding(.horizontal, 16).padding(.bottom, 8)
        .background(Q.fondFil)
    }

    private var pret: Bool {
        machine != nil && dossier != nil && !texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !envoi
    }

    private func preparer() async {
        if machine == nil { machine = machineInitiale ?? enLigne.first?.id }
        if case .success(let e) = await modele.environnements() { recents = e }
    }

    private func ouvrir() async {
        guard let machine, let dossier else { return }
        envoi = true
        let demande = DemandeOuverture(machine: machine, projet: dossier, message: texte, titre: nil, objectif: nil,
                                       autonomie: true, modele: modeleId, mode: PreferencesQuart.modeParDefaut,
                                       effort: PreferencesQuart.effortParDefaut, ultracode: nil)
        switch await modele.ouvrir(demande) {
        case .success(let s): fermer(); ouverte(s.id)
        case .failure(let e): erreur = e.description; envoi = false
        }
    }
}
#endif
