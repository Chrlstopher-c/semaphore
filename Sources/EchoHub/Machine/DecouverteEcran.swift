// Chercher un modèle sur le Hub Hugging Face, ouvrir sa fiche, lancer son
// transfert.
//
// `☠` Tout ce qui vient du Hub est ANNONCÉ, jamais mesuré. Les capacités
// affichées ici sont des déductions tirées de déclarations — l'écran le dit,
// parce que la confusion coûte cher : douze gigaoctets téléchargés pour un
// modèle qui ne sait pas ce qu'on croyait.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct DecouverteEcran: View {
    @Environment(Salon.self) private var salon
    @State private var demande = DemandeRecherche()
    @State private var saisie = ""
    @State private var etat: EtatChargement<[ResultatDepot]> = .vide
    @State private var recherche: Task<Void, Never>?

    var body: some View {
        PageAtelier("Chercher sur le Hub") {
            champ
            tri
            contenu
        }
        .onDisappear { recherche?.cancel() }
    }

    private var champ: some View {
        HStack(spacing: Trame.serre) {
            Image(systemName: "magnifyingglass").imageScale(.small)
                .foregroundStyle(Teinte.encreEteinte)
            TextField("qwen, mistral, gemma…", text: $saisie)
                .corps().foregroundStyle(Teinte.encre).tint(Teinte.accent)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { lancer() }
        }
        .padding(Trame.element)
        .background(
            Teinte.surface, in: RoundedRectangle(cornerRadius: Galbe.controle, style: .continuous)
        )
        .lisere(Galbe.controle)
    }

    /// Le tri relance la recherche : c'est une question posée au Hub, pas un
    /// classement local — la page suivante ne serait plus la même.
    private var tri: some View {
        Picker("Tri", selection: $demande.tri) {
            ForEach(TriRecherche.allCases, id: \.self) { critere in
                Text(critere.libelle).tag(critere)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: demande.tri) { _, _ in if !saisie.isEmpty { lancer() } }
    }

    @ViewBuilder private var contenu: some View {
        switch etat {
        case .vide:
            EtatCalme(
                symbole: "magnifyingglass", titre: "Rien de cherché",
                detail: "Le Hub porte des centaines de milliers de dépôts. La recherche ne "
                    + "rend que du GGUF : c'est le seul format que le PC sait charger."
            )
            .transition(.scene)
        case .chargement:
            ChargementVue().transition(.scene)
        case .echec(let raison):
            EtatCalme(
                symbole: "antenna.radiowaves.left.and.right.slash", titre: "Hub injoignable",
                detail: raison, actionTitre: "Réessayer", action: lancer
            )
            .transition(.scene)
        case .pret(let depots):
            resultats(depots)
        }
    }

    @ViewBuilder private func resultats(_ depots: [ResultatDepot]) -> some View {
        if depots.isEmpty {
            // `☠` « Rien » et « rien pour ÇA » ne se corrigent pas de la même
            // façon : la requête est redite, sinon on ne sait pas quoi changer.
            EtatCalme(
                symbole: "questionmark.circle", titre: "Aucun dépôt",
                detail: "Rien ne correspond à « \(demande.requete) » au format GGUF."
            )
            .transition(.scene)
        } else {
            SectionAtelier("Dépôts") {
                VStack(spacing: 0) {
                    ForEach(Array(depots.enumerated()), id: \.element.id) { rang, depot in
                        NavigationLink { FicheDepotEcran(depot: depot.depot) } label: {
                            LigneDepot(depot: depot)
                        }
                        .buttonStyle(.appui)
                        .entreeEnScene(rang: rang)
                    }
                }
            }
        }
    }

    /// Une recherche à la fois : sur un réseau à quatre sauts, deux réponses
    /// dans le désordre afficheraient les résultats de la requête d'avant.
    private func lancer() {
        recherche?.cancel()
        let requete = saisie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requete.isEmpty else {
            withAnimation(Elan.normal) { etat = .vide }
            return
        }
        demande.requete = requete
        demande.page = 0
        withAnimation(Elan.normal) { etat = .chargement }
        recherche = Task {
            do {
                let page = try await salon.modeles.rechercherDepots(demande)
                guard !Task.isCancelled else { return }
                withAnimation(Elan.normal) { etat = .pret(page.resultats) }
            } catch {
                guard !Task.isCancelled else { return }
                Journal.echec("recherche sur le Hub échouée : \(error)")
                withAnimation(Elan.normal) { etat = .echec(Salon.libelle(error)) }
            }
        }
    }
}

/// Un dépôt du Hub. Le `gated` et le « déjà sur le disque » sont dits AVANT
/// d'ouvrir : le premier fera échouer le transfert, le second le rendrait inutile.
struct LigneDepot: View {
    let depot: ResultatDepot

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            HStack(alignment: .top, spacing: Trame.serre) {
                Text(depot.nom).mention().foregroundStyle(Teinte.encre).lineLimit(2)
                Spacer(minLength: 0)
                if depot.dejaTelecharge { Sceau("Sur le disque").ton(.ok) }
                if depot.gated { Sceau("Licence à accepter").ton(.alerte) }
            }
            if let auteur = depot.auteur {
                Text(auteur).mesureFine().foregroundStyle(Teinte.encreEteinte).lineLimit(1)
            }
            mesures
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Trame.serre)
        .contentShape(.rect)
    }

    private var mesures: some View {
        HStack(spacing: Trame.serre) {
            if let telechargements = depot.telechargements {
                Text("\(telechargements) ↓").mesureFine()
            }
            if let taille = depot.tailleLisible {
                Text("·").mesureFine()
                Text(taille).mesureFine()
            }
            if !depot.fichiersGguf.isEmpty {
                Text("·").mesureFine()
                Text("\(depot.fichiersGguf.count) variantes").mesureFine()
            }
        }
        .foregroundStyle(Teinte.encreEteinte)
    }
}
#endif
