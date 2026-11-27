// Les fichiers du projet confié (`PanneauFichiers.tsx` du web) : l'arbre, un fichier lu, et ce que l'agent a
// modifié depuis l'instantané de référence, avec le diff. Rafraîchi toutes les 4 s tant que la feuille est
// ouverte : l'agent écrit pendant qu'on regarde.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct FichiersFeuille: View {
    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @State private var vue = Vue.arbre
    @State private var arbre: ArbreProjet?
    @State private var modifications: ModificationsProjet?
    @State private var echec: String?

    enum Vue: String, CaseIterable { case arbre = "Fichiers", modifications = "Modifications" }

    var body: some View {
        NavigationStack {
            Group {
                if let projet = salon.conversation?.projet {
                    contenu(projet)
                } else {
                    EtatCalme(symbole: "folder", titre: "Aucun projet",
                              detail: "Confie un projet à la conversation depuis la feuille Projet.")
                }
            }
            .background(Teinte.fond)
            .navigationTitle(salon.conversation?.projet ?? "Fichiers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { fermer() } } }
        }
        .task(id: salon.conversation?.projet) {
            while !Task.isCancelled {
                await relever()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private func contenu(_ projet: String) -> some View {
        List {
            Picker("Vue", selection: $vue) {
                ForEach(Vue.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            if let echec { Text(echec).foregroundStyle(Teinte.panne) }
            switch vue {
            case .arbre:
                if let arbre { NiveauVue(projet: projet, arbre: arbre, dossier: "") } else { ProgressView() }
            case .modifications: listeModifications(projet)
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder private func listeModifications(_ projet: String) -> some View {
        if let modifications {
            if let reference = modifications.reference {
                Text("Depuis : \(reference.message)").font(.caption).foregroundStyle(Teinte.encreDouce)
            }
            if modifications.fichiers.isEmpty {
                Text("Aucune modification.").foregroundStyle(Teinte.encreDouce)
            }
            ForEach(modifications.fichiers) { modification in
                NavigationLink {
                    DiffVue(projet: projet, chemin: modification.chemin)
                } label: {
                    HStack(spacing: Trame.serre) {
                        Text(modification.etat).font(.system(.caption, design: .monospaced)).bold()
                            .foregroundStyle(couleur(modification.etat))
                        Text(modification.chemin).font(.callout).foregroundStyle(Teinte.encre).lineLimit(1)
                            .truncationMode(.head)
                        Spacer()
                        if let ajouts = modification.ajouts {
                            Text("+\(ajouts)").font(.caption).foregroundStyle(Teinte.ok)
                        }
                        if let retraits = modification.suppressions {
                            Text("−\(retraits)").font(.caption).foregroundStyle(Teinte.panne)
                        }
                    }
                }
            }
        } else {
            ProgressView()
        }
    }

    private func couleur(_ etat: String) -> Color {
        switch etat {
        case "A": Teinte.ok
        case "D": Teinte.panne
        default: Teinte.alerte
        }
    }

    private func relever() async {
        guard let projet = salon.conversation?.projet else { return }
        do {
            async let lu = salon.projets.arbre(projet)
            async let modifs = salon.projets.modifications(projet)
            arbre = try await lu
            modifications = try await modifs
            echec = nil
        } catch {
            if (error as? ErreurRelais)?.estAnnulation == true { return }
            echec = Salon.libelle(error)
        }
    }
}

/// Un dossier de l'arbre ; ses sous-dossiers s'ouvrent dans la pile de navigation.
struct NiveauVue: View {
    let projet: String
    let arbre: ArbreProjet
    let dossier: String

    var body: some View {
        let niveau = NiveauArbre(arbre.fichiers, dossier: dossier)
        if niveau.dossiers.isEmpty && niveau.fichiers.isEmpty {
            Text("Dossier vide.").foregroundStyle(Teinte.encreDouce)
        }
        ForEach(niveau.dossiers, id: \.self) { nom in
            let chemin = dossier.isEmpty ? nom : "\(dossier)/\(nom)"
            NavigationLink {
                List { NiveauVue(projet: projet, arbre: arbre, dossier: chemin) }
                    .scrollContentBackground(.hidden).background(Teinte.fond)
                    .navigationTitle(nom)
            } label: {
                Label(nom, systemImage: "folder").foregroundStyle(Teinte.encre)
            }
        }
        ForEach(niveau.fichiers) { entree in
            NavigationLink {
                FichierVue(projet: projet, chemin: entree.chemin)
            } label: {
                HStack {
                    Label(entree.chemin.split(separator: "/").last.map(String.init) ?? entree.chemin,
                          systemImage: "doc.text")
                        .foregroundStyle(Teinte.encre)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(entree.taille), countStyle: .file))
                        .font(.caption).foregroundStyle(Teinte.encreEteinte)
                }
            }
        }
        if arbre.tronque && dossier.isEmpty {
            Text("Arbre tronqué : le projet compte trop de fichiers.").font(.caption).foregroundStyle(Teinte.alerte)
        }
    }
}

/// Un fichier du projet, en lecture.
struct FichierVue: View {
    @Environment(Salon.self) private var salon
    let projet: String
    let chemin: String
    @State private var fichier: ContenuFichier?
    @State private var echec: String?

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: Trame.serre) {
                if let echec { Text(echec).foregroundStyle(Teinte.panne) }
                if let fichier {
                    if fichier.binaire {
                        Text("Fichier binaire : pas d'aperçu texte.").foregroundStyle(Teinte.encreDouce)
                    } else {
                        Text(fichier.contenu ?? "").font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Teinte.encre).textSelection(.enabled)
                    }
                    if fichier.tronque {
                        Text("Tronqué : seul le début du fichier est affiché.").font(.caption).foregroundStyle(Teinte.alerte)
                    }
                } else if echec == nil {
                    ProgressView()
                }
            }
            .padding(Trame.ecran)
        }
        .background(Teinte.fond)
        .navigationTitle(chemin.split(separator: "/").last.map(String.init) ?? chemin)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let texte = fichier?.contenu {
                Button { Presse.poser(texte) } label: { Image(systemName: "doc.on.doc") }
                    .accessibilityLabel("Copier le fichier")
            }
        }
        .task {
            do { fichier = try await salon.projets.fichier(projet, chemin: chemin) } catch { echec = Salon.libelle(error) }
        }
    }
}

/// Le diff d'un fichier modifié, coloré ligne à ligne.
struct DiffVue: View {
    @Environment(Salon.self) private var salon
    let projet: String
    let chemin: String
    @State private var diff: DiffFichier?
    @State private var echec: String?

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                if let echec { Text(echec).foregroundStyle(Teinte.panne) }
                if let diff {
                    ForEach(Array(LigneDiff.lire(diff.diff).enumerated()), id: \.offset) { _, ligne in
                        rendu(ligne)
                    }
                    if diff.tronque {
                        Text("Diff tronqué.").font(.caption).foregroundStyle(Teinte.alerte).padding(.top, Trame.serre)
                    }
                } else if echec == nil {
                    ProgressView()
                }
            }
            .padding(Trame.ecran)
        }
        .background(Teinte.fond)
        .navigationTitle(chemin.split(separator: "/").last.map(String.init) ?? chemin)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { diff = try await salon.projets.diff(projet, chemin: chemin) } catch { echec = Salon.libelle(error) }
        }
    }

    private func rendu(_ ligne: LigneDiff) -> some View {
        let (texte, encre, fond): (String, Color, Color) = switch ligne {
        case .ajout(let t): (t, Teinte.ok, Teinte.ok.opacity(0.12))
        case .retrait(let t): (t, Teinte.panne, Teinte.panne.opacity(0.12))
        case .bloc(let t): (t, Teinte.accent, .clear)
        case .contexte(let t): (t, Teinte.encreDouce, .clear)
        }
        return Text(texte.isEmpty ? " " : texte)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(encre)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fond)
    }
}
#endif
