// La feuille « Tâches de fond » (étalon 012/013) : filtre « En cours », cartes avec glyphe (losange agent,
// >_ commande),
// description, genre + durée, « Voir le détail », arrêt rond à droite. Source comme Lanterne : les tâches du SDK, ou à
// défaut celles relevées dans le transcript (parité) — une session tmux / Desktop n'a que les secondes.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct TachesFeuille: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.dismiss) private var fermer
    let sessionId: String
    @State private var taches: [TacheFond]?
    @State private var erreur: String?
    @State private var enCoursSeules = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    filtre
                    contenu
                }
                .padding(.bottom, 24)
            }
            .barreFeuille("Tâches de fond")
            .toolbar { ToolbarItem(placement: .topBarLeading) { BoutonEntete(symbole: "xmark") { fermer() } } }
            .navigationDestination(for: String.self) { id in
                DetailTacheVue(sessionId: sessionId, tache: taches?.first { $0.id == id })
            }
            .refreshable { await charger() }
            .task { while !Task.isCancelled { await charger(); try? await Task.sleep(for: .seconds(5)) } }
        }
        .feuilleQuart()
    }

    private var filtre: some View {
        Menu {
            Button("En cours") { enCoursSeules = true }
            Button("Toutes") { enCoursSeules = false }
        } label: {
            HStack(spacing: 6) {
                Text(enCoursSeules ? "En cours" : "Toutes")
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .medium))
            }
            .font(Q.rangee).foregroundStyle(Q.tertiaire).padding(.horizontal, 24).frame(height: 36)
        }
    }

    @ViewBuilder private var contenu: some View {
        let liste = (taches ?? []).filter { !enCoursSeules || $0.enCours }
        if taches == nil && erreur == nil {
            IndicateurTravail().frame(width: 18, height: 18).frame(maxWidth: .infinity).padding(.top, 40)
        } else if let erreur, taches == nil {
            Text(erreur).font(Q.detail).foregroundStyle(Q.tertiaire).padding(.horizontal, 32)
        } else if liste.isEmpty {
            Text(enCoursSeules ? "Aucune tâche en cours." : "Aucune tâche de fond dans cette session.")
                .font(Q.detail).foregroundStyle(Q.tertiaire).frame(maxWidth: .infinity).padding(.top, 40)
        }
        ForEach(liste) { t in CarteTache(tache: t) { arreter(t) } }
    }

    private func charger() async {
        switch await modele.tachesFond(de: sessionId) {
        case .success(let t): taches = t; erreur = nil
        case .failure(let e): erreur = e.description
        }
    }

    private func arreter(_ t: TacheFond) {
        Task {
            if let e = await modele.arreterTache(t.id, de: modele.sourceLecture(sessionId)) { erreur = e }
            await charger()
        }
    }
}

private struct CarteTache: View {
    let tache: TacheFond
    let arreter: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: tache.genre == .agent ? "diamond" : "apple.terminal")
                .font(.system(size: 18, weight: .light)).foregroundStyle(Q.texte).frame(width: 26).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(tache.description).font(Q.rangee).foregroundStyle(Q.tertiaire).lineLimit(2)
                HStack(spacing: 14) {
                    Text(tache.genre == .agent ? "Agent" : "Commande").font(Q.rangee).foregroundStyle(Q.texte)
                    TimelineView(.periodic(from: .now, by: 1)) { contexte in
                        Text(Format.duree(secondes: TachesFond.duree(tache, maintenant: contexte.date)))
                            .font(Q.rangee).foregroundStyle(Q.tertiaire).monospacedDigit()
                    }
                    if !tache.enCours { Text(tache.statut).font(Q.detail).foregroundStyle(Q.tertiaire) }
                }
                NavigationLink(value: tache.id) { Text("Voir le détail").font(Q.rangee).foregroundStyle(Q.lienDoux) }
            }
            Spacer(minLength: 4)
            if tache.arretable {
                Button(action: arreter) {
                    Image(systemName: "stop.circle").font(.system(size: 24, weight: .light))
                        .foregroundStyle(Q.secondaire)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Arrêter")
            }
        }
        .padding(.leading, 20).padding(.trailing, 8).padding(.vertical, 14)
        .background(Q.carte, in: .rect(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, Q.marge)
    }
}

/// Détail : état, modèle ; pour une tâche du transcript, sa consigne et ses dernières actions.
private struct DetailTacheVue: View {
    @Environment(ModeleRelais.self) private var modele
    let sessionId: String
    let tache: TacheFond?
    @State private var detail: DetailTacheParite?

    var body: some View {
        ScrollView {
            if let t = tache { corps(t) }
        }
        .barreFeuille("Tâche")
        .task {
            guard let t = tache, t.deParite else { return }
            if case .success(let d) = await modele.detailTacheParite(t.id, de: sessionId) { detail = d }
        }
    }

    private func corps(_ t: TacheFond) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t.description).font(.system(size: 18)).foregroundStyle(Q.texte).padding(.horizontal, Q.margeTexte)
            TitreSection(texte: "Détail")
            Carte {
                RangeeReglage(titre: "État", valeur: t.statut, chevron: false)
                if let m = t.modele {
                    Filet()
                    RangeeReglage(titre: "Modèle", valeur: CatalogueModeles.nom(id: m), chevron: false)
                }
            }
            if let p = detail?.prompt, !p.isEmpty {
                TitreSection(texte: t.genre == .agent ? "Consigne" : "Commande")
                BlocCode(titre: nil, texte: p).padding(.horizontal, Q.marge)
            }
            if let a = detail?.activite, !a.isEmpty {
                TitreSection(texte: "Activité")
                BlocCode(titre: nil, texte: a).padding(.horizontal, Q.marge)
            }
        }
        .padding(.vertical, 12)
    }
}
#endif
