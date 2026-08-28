// L'écran principal : la besace. Ce qu'on a capturé, épingles en tête, avec
// recherche et filtre par tag. C'est ici que Chris passe le plus de temps —
// priorité à l'intuitivité : on voit tout de suite ses dernières captures.
#if canImport(SwiftUI)
import SwiftUI
import SailyNoyau

struct InboxEcran: View {
    @Environment(Boite.self) private var boite
    @State private var recherche = ""
    @State private var tagActif: String?
    /// La note en cours d'édition, présentée en feuille. `nil` = aucune.
    @State private var noteAEditer: Item?

    var body: some View {
        ZStack {
            Teinte.fond.ignoresSafeArea()
            VStack(spacing: 0) {
                enTete
                corps
            }
        }
        .sheet(item: $noteAEditer) { note in
            EditionNoteEcran(item: note)
                .environment(boite)
                .presentationDetents([.medium, .large])
                .presentationBackground(Teinte.fond)
        }
    }

    // MARK: - En-tête

    private var enTete: some View {
        VStack(spacing: Trame.element) {
            HStack(alignment: .firstTextBaseline) {
                Fronton("Besace")
                Spacer(minLength: 0)
                bandeauLiaison.padding(.trailing, Trame.ecran)
            }
            BarreRecherche(texte: $recherche)
                .padding(.horizontal, Trame.ecran)
            if !boite.tags.isEmpty { rubanTags }
        }
        .padding(.top, Trame.serre)
        .padding(.bottom, Trame.element)
    }

    @ViewBuilder
    private var bandeauLiaison: some View {
        switch boite.liaison {
        case .demarrage:
            Sceau("Connexion…", symbole: "antenna.radiowaves.left.and.right").ton(.neutre)
        case .enLigne:
            Sceau("En ligne", symbole: "dot.radiowaves.up.forward").ton(.actif)
        case .horsLigne:
            Sceau(boite.enAttente > 0 ? "\(boite.enAttente) en attente" : "Hors ligne",
                  symbole: "bolt.horizontal").ton(.alerte)
        case .injoignable:
            Sceau("Injoignable", symbole: "exclamationmark.triangle.fill").ton(.panne)
        }
    }

    private var rubanTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Trame.serre) {
                Button { basculerTag(nil) } label: {
                    Etiquette("Tout", actif: tagActif == nil)
                }
                .buttonStyle(.appui)
                ForEach(boite.tags, id: \.self) { tag in
                    Button { basculerTag(tag) } label: {
                        Etiquette(tag, actif: tagActif == tag)
                    }
                    .buttonStyle(.appui)
                }
            }
            .padding(.horizontal, Trame.ecran)
        }
    }

    // MARK: - Corps

    @ViewBuilder
    private var corps: some View {
        if !boite.premierChargementFait {
            EtatCalme(symbole: "tray", titre: "Ouverture de la besace…",
                      detail: "On récupère tes captures.")
            .frame(maxHeight: .infinity)
        } else if itemsFiltres.isEmpty {
            etatVide.frame(maxHeight: .infinity)
        } else {
            liste
        }
    }

    private var liste: some View {
        ScrollView {
            LazyVStack(spacing: Trame.element) {
                ForEach(Array(itemsFiltres.enumerated()), id: \.element.id) { rang, item in
                    CarteItem(
                        item: item,
                        surEpingle: { Task { await boite.basculerEpingle(item) } },
                        surSuppression: { Task { await boite.supprimer(item) } },
                        surEdition: item.kind == .note ? { noteAEditer = item } : nil
                    )
                    .entreeEnScene(rang: rang)
                    .transition(.item)
                }
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.vertical, Trame.element)
            .animation(Elan.normal, value: itemsFiltres.map(\.id))
        }
    }

    @ViewBuilder
    private var etatVide: some View {
        if recherche.isEmpty && tagActif == nil {
            EtatCalme(
                symbole: "tray", titre: "Besace vide",
                detail: "Balance ta première note, un lien, une image — depuis l'onglet Capturer."
            )
        } else {
            EtatCalme(
                symbole: "magnifyingglass", titre: "Rien ne correspond",
                detail: "Aucun item pour cette recherche.",
                actionTitre: "Effacer les filtres", action: { effacerFiltres() }
            )
        }
    }

    // MARK: - Filtrage

    private var itemsFiltres: [Item] {
        boite.items.filter { item in
            correspondTag(item) && correspondRecherche(item)
        }
    }

    private func correspondTag(_ item: Item) -> Bool {
        guard let tagActif else { return true }
        return item.tags.contains(tagActif)
    }

    private func correspondRecherche(_ item: Item) -> Bool {
        let terme = recherche.trimmingCharacters(in: .whitespaces).lowercased()
        guard !terme.isEmpty else { return true }
        if item.text.lowercased().contains(terme) { return true }
        if item.url?.lowercased().contains(terme) == true { return true }
        return item.tags.contains { $0.lowercased().contains(terme) }
    }

    private func basculerTag(_ tag: String?) {
        withAnimation(Elan.micro) { tagActif = (tagActif == tag) ? nil : tag }
    }

    private func effacerFiltres() {
        withAnimation(Elan.micro) {
            recherche = ""
            tagActif = nil
        }
    }
}

/// Le champ de recherche de la besace. Un composant à part : il porte son
/// glyphe, son fond et son bouton d'effacement.
struct BarreRecherche: View {
    @Binding var texte: String

    var body: some View {
        HStack(spacing: Trame.serre) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Teinte.encreEteinte)
            TextField("Chercher dans la besace", text: $texte)
                .textFieldStyle(.plain)
                .corps()
                .foregroundStyle(Teinte.encre)
                .tint(Teinte.accent)
                .autocorrectionDisabled()
            if !texte.isEmpty {
                Button { texte = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Teinte.encreEteinte)
                }
                .buttonStyle(.appui)
            }
        }
        .padding(.horizontal, Trame.bloc)
        .frame(height: Trame.cible)
        .background(Teinte.surface, in: .rect(cornerRadius: Galbe.controle, style: .continuous))
        .lisere(Galbe.controle)
    }
}
#endif
