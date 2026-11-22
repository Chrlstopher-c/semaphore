// La feuille « Tâches de fond » (étalon 012/013) : filtre « En cours », cartes avec glyphe (losange agent, >_ shell),
// description, genre + durée, « Voir le détail » et bouton d'arrêt rond à droite.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct TachesFeuille: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.dismiss) private var fermer
    let sessionId: String
    @State private var taches: [TacheSession]?
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
            .navigationDestination(for: String.self) { id in DetailTacheVue(tache: taches?.first { $0.id == id }) }
            .refreshable { await charger() }
            .task { while !Task.isCancelled { await charger(); try? await Task.sleep(for: .seconds(4)) } }
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
        let liste = (taches ?? []).filter { !enCoursSeules || $0.statut == "en_cours" || $0.statut == "en_attente" }
        if taches == nil && erreur == nil {
            IndicateurTravail().frame(width: 18, height: 18).frame(maxWidth: .infinity).padding(.top, 40)
        } else if let erreur {
            Text(erreur).font(Q.detail).foregroundStyle(Q.tertiaire).padding(.horizontal, 32)
        } else if liste.isEmpty {
            Text(enCoursSeules ? "Aucune tâche en cours." : "Aucune tâche de fond dans cette session.").font(Q.detail)
                .foregroundStyle(Q.tertiaire).frame(maxWidth: .infinity).padding(.top, 40)
        }
        ForEach(liste, id: \.id) { t in CarteTache(tache: t) { arreter(t) } }
    }

    private func charger() async {
        switch await modele.taches(de: sessionId) {
        case .success(let t): taches = t; erreur = nil
        case .failure(let e): if taches == nil { erreur = e.description }
        }
    }

    private func arreter(_ t: TacheSession) {
        Task {
            if let e = await modele.arreterTache(t.id, de: sessionId) { erreur = e } else { await charger() }
        }
    }
}

private struct CarteTache: View {
    let tache: TacheSession
    let arreter: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: tache.sousAgent != nil || tache.type.contains("agent") ? "diamond" : "apple.terminal")
                .font(.system(size: 18, weight: .light)).foregroundStyle(Q.texte).frame(width: 26).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(tache.description).font(Q.rangee).foregroundStyle(Q.tertiaire).lineLimit(2)
                HStack(spacing: 14) {
                    Text(tache.sousAgent != nil ? "Agent" : "Shell").font(Q.rangee).foregroundStyle(Q.texte)
                    Text(Format.duree(secondes: tache.dureeMs / 1000))
                        .font(Q.rangee)
                        .foregroundStyle(Q.tertiaire)
                        .monospacedDigit()
                }
                NavigationLink(value: tache.id) { Text("Voir le détail").font(Q.rangee).foregroundStyle(Q.lienDoux) }
            }
            Spacer(minLength: 4)
            if tache.statut == "en_cours" || tache.statut == "en_attente" {
                Button(action: arreter) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 24, weight: .light))
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

private struct DetailTacheVue: View {
    let tache: TacheSession?

    var body: some View {
        ScrollView {
            if let t = tache {
                corps(t)
                    .padding(.vertical, 12)
            }
        }
        .barreFeuille("Tâche")
    }

    private func corps(_ t: TacheSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t.description)
                .font(.system(size: 18))
                .foregroundStyle(Q.texte)
                .padding(.horizontal, Q.margeTexte)
            TitreSection(texte: "Détail")
            Carte {
                RangeeReglage(
                    titre: "État",
                    valeur: t.statut.replacingOccurrences(of: "_", with: " "),
                    chevron: false)
                Filet()
                RangeeReglage(titre: "Outils", valeur: "\(t.outils)", chevron: false)
                Filet()
                RangeeReglage(titre: "Jetons", valeur: Format.tokens(t.jetons), chevron: false)
                if let m = t.modele {
                    Filet()
                    RangeeReglage(
                        titre: "Modèle",
                        valeur: CatalogueModeles.nom(id: m),
                        chevron: false)
                }
            }
            if let a = t.activite {
                TitreSection(texte: "Activité")
                BlocCode(titre: nil, texte: a)
                    .padding(.horizontal, Q.marge)
            }
        }
    }
}
#endif
